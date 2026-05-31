import CommenterDomain
import Foundation

public enum ReportGenerationError: LocalizedError, Equatable {
    case invalidDataset([String])
    case missingAchievementLevel(studentName: String, subject: String)
    case unavailableSubject(String)
    case noEligibleComment(studentName: String, subject: String)
    case unresolvedPlaceholders(label: String, placeholders: [String])
    case unsafeTeacherText(label: String, message: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidDataset(issues):
            return "Comment engine data is unavailable: \(issues.joined(separator: " "))"
        case let .missingAchievementLevel(studentName, subject):
            return "Missing achievement level for \(studentName) in \(subject)."
        case let .unavailableSubject(message):
            return message
        case let .noEligibleComment(studentName, subject):
            return "Draft comments could not be created for \(studentName) in \(subject). Check the result, focus area, and report note, then try again."
        case let .unresolvedPlaceholders(label, placeholders):
            return "\(label) contains template text that must be replaced: \(placeholders.joined(separator: ", "))"
        case let .unsafeTeacherText(label, message):
            return message.hasPrefix(label) ? message : "\(label) \(message)"
        }
    }
}

public struct ReportGenerator {
    private let data: CommentEngineData
    private let projectMetadata: ProjectMetadata
    private var usedVariantIds: Set<String>
    private var usageCounts: [String: Int]
    private let bandMapping: [String: String]
    private let maxUsagePerClass: Int
    private let minVariantDistance: Int
    private let componentIndex: [String: Component]
    private let variantOrder: [String: Int]

    public init(
        data: CommentEngineData,
        projectMetadata: ProjectMetadata,
        usedVariantIds: Set<String> = [],
        existingUsage: [String: Int] = [:]
    ) throws {
        guard !data.componentBank.isEmpty else {
            throw ReportGenerationError.invalidDataset(["ComponentBank has no eligible records."])
        }
        guard !data.recipeBank.isEmpty else {
            throw ReportGenerationError.invalidDataset(["RecipeBank has no eligible records."])
        }

        self.data = data
        self.projectMetadata = projectMetadata
        let positiveUsage = existingUsage.filter { $0.value > 0 }
        self.usedVariantIds = usedVariantIds.union(positiveUsage.keys)
        self.usageCounts = positiveUsage
        self.bandMapping = projectMetadata.bandMapping ?? Self.detectBandMapping(data)
        self.maxUsagePerClass = Self.uniquenessNumber(data, keys: ["MaxUsagePerClass", "MaxUsage"], defaultValue: Int.max)
        self.minVariantDistance = Self.uniquenessNumber(data, keys: ["MinVariantDistance"], defaultValue: 0)
        self.componentIndex = data.componentBank.reduce(into: [:]) { index, component in
            index[component.keyID] = component
        }
        self.variantOrder = data.assembledVariants.enumerated().reduce(into: [:]) { index, entry in
            index[entry.element.variantID] = entry.offset
        }
    }

    public func usageSnapshot() -> [String: Int] {
        usageCounts
    }

    public mutating func generateReport(
        student: Student,
        subject: String,
        result: AchievementResult,
        generatedAt: Int64
    ) throws -> GeneratedReport {
        var trace: [String] = []
        let displayName = getDisplayName(student: student, projectMetadata: projectMetadata)

        guard let achievementLevel = result.achievementLevel else {
            throw ReportGenerationError.missingAchievementLevel(studentName: displayName, subject: subject)
        }

        let mappedBand = bandMapping[achievementLevel.rawValue] ?? achievementLevel.rawValue
        let normalizedLevel = Self.normalizeLevel(student.yearLevel.rawValue)
        let subjectResolution = resolveSubjectForGeneration(uiSubject: subject, data: data, focusStrand: result.focusStrand)
        guard subjectResolution.eligible, !subjectResolution.candidates.isEmpty else {
            throw ReportGenerationError.unavailableSubject(subjectResolution.reason ?? "Draft comments are not available for \(subject) yet.")
        }

        let concreteSubject = subjectResolution.selectedDataSubject ?? subjectResolution.candidates[0]
        let context = buildPlaceholderContext(
            student: student,
            subject: concreteSubject,
            result: result,
            projectMetadata: projectMetadata
        )
        let repairContext = createTeacherTextRepairContext(student: student, placeholderContext: context)
        let repairedEvidence = repairEvidenceText(result.evidenceText, context: repairContext)
        if hasBlockingRepairIssue(repairedEvidence.issues) {
            throw ReportGenerationError.unsafeTeacherText(label: "Evidence", message: blockingRepairMessage(label: "Evidence", issues: repairedEvidence.issues))
        }
        let generationContext = buildPlaceholderContext(
            student: student,
            subject: concreteSubject,
            result: result,
            projectMetadata: projectMetadata,
            overrides: repairedEvidence.specificTaskPhrase.map { ["specificTask": $0] } ?? [:]
        )

        trace.append("Request: \(subject); candidates: \(subjectResolution.candidates.joined(separator: ", ")); text subject: \(concreteSubject); level: \(student.yearLevel.rawValue) -> \(normalizedLevel); band: \(achievementLevel.rawValue) -> \(mappedBand)")

        let generated = findVariantCandidate(
            dataSubjects: subjectResolution.candidates,
            normalizedLevel: normalizedLevel,
            mappedBand: mappedBand,
            result: result,
            context: generationContext,
            trace: &trace
        ) ?? assembleFromComponents(
            dataSubjects: subjectResolution.candidates,
            normalizedLevel: normalizedLevel,
            mappedBand: mappedBand,
            result: result,
            context: generationContext,
            trace: &trace
        )

        guard let generated else {
            throw ReportGenerationError.noEligibleComment(studentName: generationContext.displayName, subject: subject)
        }

        let subjectText = try decorateSubjectText(
            generated.text,
            student: student,
            subject: concreteSubject,
            result: result,
            context: generationContext,
            repairContext: repairContext,
            repairedEvidence: repairedEvidence,
            trace: &trace
        )
        let finalText = applyReportLayout(
            subjectText,
            student: student,
            subject: concreteSubject,
            result: result,
            context: generationContext
        )
        let unresolved = findUnresolvedPlaceholders(finalText)
        guard unresolved.isEmpty else {
            throw ReportGenerationError.unresolvedPlaceholders(label: "\(generationContext.displayName) \(subject) report", placeholders: unresolved)
        }

        recordUsage(generated.variantID)

        return GeneratedReport(
            studentId: student.id,
            subject: subject,
            concreteSubject: concreteSubject == subject ? nil : concreteSubject,
            text: finalText,
            variantIds: [generated.variantID],
            trace: trace.joined(separator: " | "),
            isLocked: false,
            generatedAt: generatedAt,
            resultFingerprint: buildGenerationFingerprint(projectMetadata: projectMetadata, student: student, result: result, concreteSubject: concreteSubject)
        )
    }

    private func findVariantCandidate(
        dataSubjects: [String],
        normalizedLevel: String,
        mappedBand: String,
        result: AchievementResult,
        context: PlaceholderContext,
        trace: inout [String]
    ) -> GeneratedCandidate? {
        let normalizedSubjects = Set(dataSubjects.map(normalizeSubjectLabel))
        let normalizedFocus = normalizeStrand(result.focusStrand ?? "")
        var allCandidates: [VariantCandidate] = []
        var focusCandidates: [VariantCandidate] = []
        var subjectMatchCount = 0
        var levelMatchCount = 0
        var bandMatchCount = 0
        var placeholderRejected = 0
        var uniquenessRejected = 0

        for variant in data.assembledVariants {
            guard let component = componentIndex[variant.keyID] else { continue }
            guard normalizedSubjects.contains(normalizeSubjectLabel(component.subject)) else { continue }
            subjectMatchCount += 1

            guard Self.levelMatches(component.level, normalizedLevel: normalizedLevel) else { continue }
            levelMatchCount += 1

            guard Self.bandMatches(component.band, mappedBand: mappedBand) else { continue }
            bandMatchCount += 1

            guard canUseVariant(variant.variantID) else {
                uniquenessRejected += 1
                continue
            }

            let resolved = resolveReportPlaceholders(text: variant.text, context: context)
            guard resolved.unresolved.isEmpty, resolved.missingContext.isEmpty else {
                placeholderRejected += 1
                continue
            }

            let candidate = VariantCandidate(variant: variant, component: component, renderedText: resolved.text)
            allCandidates.append(candidate)
            if !normalizedFocus.isEmpty, normalizeStrand(component.strand ?? "").contains(normalizedFocus) {
                focusCandidates.append(candidate)
            }
        }

        trace.append("Variant subject matches: \(subjectMatchCount)")
        trace.append("Variant level matches: \(levelMatchCount)")
        trace.append("Variant band matches: \(bandMatchCount)")
        trace.append("Rejected by placeholders/context: \(placeholderRejected)")
        trace.append("Rejected by uniqueness: \(uniquenessRejected)")

        let pool = focusCandidates.isEmpty ? allCandidates : focusCandidates
        if !focusCandidates.isEmpty {
            trace.append("Focus matched: \(result.focusStrand ?? "")")
        }
        return selectBestVariant(pool).map { GeneratedCandidate(text: $0.renderedText, variantID: $0.variant.variantID) }
    }

    private func assembleFromComponents(
        dataSubjects: [String],
        normalizedLevel: String,
        mappedBand: String,
        result: AchievementResult,
        context: PlaceholderContext,
        trace: inout [String]
    ) -> GeneratedCandidate? {
        let normalizedSubjects = Set(dataSubjects.map(normalizeSubjectLabel))
        let normalizedFocus = normalizeStrand(result.focusStrand ?? "")
        let filteredComponents = data.componentBank.filter { component in
            normalizedSubjects.contains(normalizeSubjectLabel(component.subject))
                && Self.levelMatches(component.level, normalizedLevel: normalizedLevel)
                && Self.bandMatches(component.band, mappedBand: mappedBand)
        }

        func components(type: Component.ComponentType) -> [ComponentCandidate] {
            let eligible = filteredComponents.compactMap { component -> ComponentCandidate? in
                guard component.type == type else { return nil }
                let rendered = resolveReportPlaceholders(text: component.text, context: context)
                guard rendered.unresolved.isEmpty, rendered.missingContext.isEmpty else { return nil }
                return ComponentCandidate(component: component, renderedText: rendered.text)
            }
            let focused = normalizedFocus.isEmpty ? [] : eligible.filter { normalizeStrand($0.component.strand ?? "").contains(normalizedFocus) }
            return (focused.isEmpty ? eligible : focused).sorted { $0.component.keyID < $1.component.keyID }
        }

        guard let strength = components(type: .strength).first,
              let nextStep = components(type: .nextStep).first
        else {
            trace.append("Component assembly unavailable: missing eligible Strength or NextStep component.")
            return nil
        }

        let evidence = components(type: .evidence).first
        let parts = [strength.renderedText, evidence?.renderedText, nextStep.renderedText]
            .compactMap { $0?.trimmedNonEmpty }
            .map(Self.ensureSentence)
        let sourceIds = [strength.component.keyID, evidence?.component.keyID, nextStep.component.keyID].compactMap { $0 }
        let variantID = "ASSEMBLED_\(String(Self.fnv1a(sourceIds.joined(separator: "|")), radix: 16))"

        guard canUseVariant(variantID) else {
            trace.append("Component assembly blocked by uniqueness rules.")
            return nil
        }

        trace.append("Assembled comment from eligible components.")
        return GeneratedCandidate(text: cleanSpacing(parts.joined(separator: " ")), variantID: variantID)
    }

    private func selectBestVariant(_ variants: [VariantCandidate]) -> VariantCandidate? {
        variants.sorted { left, right in
            let leftCount = usageCounts[left.variant.variantID] ?? 0
            let rightCount = usageCounts[right.variant.variantID] ?? 0
            if leftCount != rightCount { return leftCount < rightCount }
            let leftOrder = variantOrder[left.variant.variantID] ?? Int.max
            let rightOrder = variantOrder[right.variant.variantID] ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            return left.variant.variantID < right.variant.variantID
        }.first
    }

    private func decorateSubjectText(
        _ baseText: String,
        student: Student,
        subject: String,
        result: AchievementResult,
        context: PlaceholderContext,
        repairContext: TeacherTextRepairContext,
        repairedEvidence: RepairedEvidenceText,
        trace: inout [String]
    ) throws -> String {
        var subjectText = cleanSpacing(baseText)

        if !repairedEvidence.appendedText.isEmpty {
            let evidencePhrase = repairedEvidence.specificTaskPhrase ?? ""
            let evidenceAlreadyCovered = !evidencePhrase.isEmpty && subjectText.lowercased().contains(evidencePhrase.lowercased())
            if evidenceAlreadyCovered {
                trace.append("Teacher evidence was used through a safe specific task phrase.")
            } else {
                subjectText = "\(Self.ensureSentence(subjectText)) \(repairedEvidence.appendedText)"
            }
        }

        let normalizedSubject = normalizeSubjectLabel(subject)
        if normalizedSubject == "english", let englishFocus = generateEnglishFocusSentence(student: student, subject: subject, result: result, displayName: context.displayName, pronouns: context) {
            subjectText = "\(Self.ensureSentence(subjectText)) \(englishFocus)"
        } else if normalizedSubject == "mathematics", let mathProficiency = generateMathProficiencySentence(student: student, subject: subject, result: result, displayName: context.displayName, pronouns: context) {
            subjectText = "\(Self.ensureSentence(subjectText)) \(mathProficiency)"
        }

        subjectText = appendFlagSentences(subjectText, flags: result.flags, student: student, subject: subject, displayName: context.displayName)

        let noteSentence = try generateTeacherNoteSentence(student: student, result: result, repairContext: repairContext)
        if !noteSentence.isEmpty {
            trace.append("Teacher/student note emphasis included.")
            subjectText = "\(Self.ensureSentence(subjectText)) \(noteSentence)"
        }
        return cleanSpacing(subjectText)
    }

    private func applyReportLayout(
        _ subjectText: String,
        student: Student,
        subject: String,
        result: AchievementResult,
        context: PlaceholderContext
    ) -> String {
        let reportLayout = normalizeReportLayout(projectMetadata.reportLayout)
        if !reportLayout.enabled { return cleanSpacing(subjectText) }

        let paragraphs: [ReportSection: String] = [
            .general: generateGeneralParagraph(student: student, subject: subject, displayName: context.displayName),
            .subject: subjectText,
            .dispositions: generateDispositionsParagraph(result: result, displayName: context.displayName),
            .nextSteps: generateNextStepsParagraph(student: student, subject: subject, result: result, displayName: context.displayName)
        ]

        return reportLayout.order
            .filter { reportLayout.include[$0] != false }
            .compactMap { paragraphs[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty }
            .joined(separator: "\n\n")
    }

    private func generateGeneralParagraph(student: Student, subject: String, displayName: String) -> String {
        guard let attitude = student.attitudeDescriptor?.trimmedNonEmpty else { return "" }
        let templates = [
            "{Name} is a {attitude} learner who approaches {Subject} with enthusiasm.",
            "A {attitude} learner, {Name} engages positively with {Subject} content.",
            "{Name} approaches learning in a {attitude} manner and participates actively in {Subject}."
        ]
        let hash = Self.fnv1a("\(student.id)::\(subject)::\(projectMetadata.id)::general")
        return templates[Int(hash % UInt32(templates.count))]
            .replacingOccurrences(of: "{Name}", with: displayName)
            .replacingOccurrences(of: "{attitude}", with: attitude)
            .replacingOccurrences(of: "{Subject}", with: subject)
    }

    private func generateEnglishFocusSentence(student: Student, subject: String, result: AchievementResult, displayName: String, pronouns: PlaceholderContext) -> String? {
        let tags = stableOrderedArray(result.englishFocusTags)
        guard !tags.isEmpty else { return nil }
        let hash = Self.fnv1a("\(student.id)::\(subject)::english-focus")
        let template: String
        if tags.count == 1 {
            template = englishFocusTemplatesSingle[Int(hash % UInt32(englishFocusTemplatesSingle.count))]
                .replacingOccurrences(of: "{tag}", with: tags[0])
        } else {
            template = englishFocusTemplatesDouble[Int(hash % UInt32(englishFocusTemplatesDouble.count))]
                .replacingOccurrences(of: "{tag1}", with: tags[0])
                .replacingOccurrences(of: "{tag2}", with: tags[1])
        }
        return replacePronounTemplateTokens(template, displayName: displayName, pronouns: pronouns)
    }

    private func generateMathProficiencySentence(student: Student, subject: String, result: AchievementResult, displayName: String, pronouns: PlaceholderContext) -> String? {
        let proficiencies = stableOrderedArray(result.mathProficiencies)
        guard !proficiencies.isEmpty else { return nil }
        let hash = Self.fnv1a("\(student.id)::\(subject)::math-prof")
        let template: String
        if proficiencies.count == 1 {
            template = mathProficiencyTemplatesSingle[Int(hash % UInt32(mathProficiencyTemplatesSingle.count))]
                .replacingOccurrences(of: "{prof}", with: proficiencies[0])
        } else {
            template = mathProficiencyTemplatesDouble[Int(hash % UInt32(mathProficiencyTemplatesDouble.count))]
                .replacingOccurrences(of: "{prof1}", with: proficiencies[0])
                .replacingOccurrences(of: "{prof2}", with: proficiencies[1])
        }
        return replacePronounTemplateTokens(template, displayName: displayName, pronouns: pronouns)
    }

    private func generateDispositionsParagraph(result: AchievementResult, displayName: String) -> String {
        let fragments = stableOrderedArray(result.mathMindsetToggles).map(mindsetToFragment)
        if fragments.isEmpty { return "" }
        if fragments.count == 1 { return "\(displayName) \(fragments[0])." }
        if fragments.count == 2 { return "\(displayName) \(fragments[0]) and \(fragments[1])." }
        let last = fragments[fragments.count - 1]
        return "\(displayName) \(fragments.dropLast().joined(separator: ", ")), and \(last)."
    }

    private func generateNextStepsParagraph(student: Student, subject: String, result: AchievementResult, displayName: String) -> String {
        let goals = stableOrderedArray(result.nextStepGoals)
        guard !goals.isEmpty else { return "" }
        let hash = Self.fnv1a("\(student.id)::\(subject)::next-steps")
        if goals.count == 1 {
            return nextStepTemplatesSingle[Int(hash % UInt32(nextStepTemplatesSingle.count))]
                .replacingOccurrences(of: "{Name}", with: displayName)
                .replacingOccurrences(of: "{goal}", with: goals[0])
        }
        return nextStepTemplatesDouble[Int(hash % UInt32(nextStepTemplatesDouble.count))]
            .replacingOccurrences(of: "{Name}", with: displayName)
            .replacingOccurrences(of: "{goal1}", with: goals[0])
            .replacingOccurrences(of: "{goal2}", with: goals[1])
    }

    private func sanitizeNote(_ value: String?, label: String) throws -> String {
        let trimmed = cleanSpacing((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        if trimmed.isEmpty { return "" }
        if !findUnresolvedPlaceholders(trimmed).isEmpty {
            throw ReportGenerationError.unsafeTeacherText(label: label, message: "still contains template text that must be replaced.")
        }
        if trimmed.count > 180 {
            throw ReportGenerationError.unsafeTeacherText(label: label, message: "must be 180 characters or fewer before generation.")
        }
        return trimmed
    }

    private func generateTeacherNoteSentence(student: Student, result: AchievementResult, repairContext: TeacherTextRepairContext) throws -> String {
        let notes = [
            try sanitizeNote(student.reportEmphasisNote, label: "Student report emphasis note"),
            try sanitizeNote(result.reportEmphasisNote, label: "Result report emphasis note")
        ].filter { !$0.isEmpty }
        guard !notes.isEmpty else { return "" }

        let repaired = repairReportNoteText(notes.joined(separator: " "), context: repairContext)
        if hasBlockingRepairIssue(repaired.issues) {
            throw ReportGenerationError.unsafeTeacherText(label: "Report note", message: blockingRepairMessage(label: "Report note", issues: repaired.issues))
        }
        return repaired.text
    }

    private func appendFlagSentences(_ text: String, flags: [String: Bool]?, student: Student, subject: String, displayName: String) -> String {
        guard let flags else { return text }
        var updated = cleanSpacing(text)
        reportFlags.forEach { flag in
            guard flags[flag.id] == true else { return }
            let hash = Self.fnv1a("\(student.id)::\(subject)::\(flag.id)")
            let sentence = flag.sentences[Int(hash % UInt32(flag.sentences.count))]
                .replacingOccurrences(of: "[StudentName]", with: displayName)
                .replacingOccurrences(of: "[Student Name]", with: displayName)
                .replacingOccurrences(of: "[Subject]", with: subject)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return }
            updated = "\(Self.ensureSentence(updated)) \(sentence)"
        }
        return cleanSpacing(updated)
    }

    private func replacePronounTemplateTokens(_ template: String, displayName: String, pronouns: PlaceholderContext) -> String {
        template
            .replacingOccurrences(of: "{Name}", with: displayName)
            .replacingOccurrences(of: "{HeShe}", with: pronouns.heShe)
            .replacingOccurrences(of: "{heshe}", with: pronouns.heSheLower)
            .replacingOccurrences(of: "{HisHer}", with: pronouns.hisHer)
            .replacingOccurrences(of: "{hisher}", with: pronouns.hisHer)
    }

    private func canUseVariant(_ variantID: String) -> Bool {
        let current = usageCounts[variantID] ?? 0
        if current >= maxUsagePerClass { return false }
        if minVariantDistance <= 0 || usedVariantIds.isEmpty { return true }

        guard let order = variantOrder[variantID] else {
            return current == 0
        }
        for usedID in usedVariantIds {
            guard let usedOrder = variantOrder[usedID] else { continue }
            if abs(order - usedOrder) < minVariantDistance {
                return false
            }
        }
        return true
    }

    private mutating func recordUsage(_ variantID: String) {
        usageCounts[variantID, default: 0] += 1
        usedVariantIds.insert(variantID)
    }

    private static func levelMatches(_ componentLevel: String, normalizedLevel: String) -> Bool {
        let normalized = normalizeLevel(componentLevel)
        return normalized == normalizedLevel || normalized == "5/6" || normalized == "mixed"
    }

    private static func bandMatches(_ componentBand: String, mappedBand: String) -> Bool {
        componentBand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == mappedBand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizeLevel(_ level: String) -> String {
        let normalized = level.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.contains("5"), normalized.contains("6") { return "5/6" }
        if normalized.contains("5") { return "5" }
        if normalized.contains("6") { return "6" }
        return normalized
    }

    private func normalizeStrand(_ strand: String) -> String {
        strand
            .lowercased()
            .replacingOccurrences(of: "\u{00a0}", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ensureSentence(_ value: String) -> String {
        let text = cleanSpacing(value)
        return text.range(of: #"[.!?]$"#, options: .regularExpression) == nil ? "\(text)." : text
    }

    private static func uniquenessNumber(_ data: CommentEngineData, keys: [String], defaultValue: Int) -> Int {
        for key in keys {
            if let rule = data.uniquenessGuard.first(where: { $0.rule == key }), rule.value.isFinite {
                return Int(rule.value)
            }
        }
        return defaultValue
    }

    private static func detectBandMapping(_ data: CommentEngineData) -> [String: String] {
        let bands = data.componentBank.map(\.band)
        let defaults = ["Beginning", "Developing", "At Standard", "Above Standard"]
        var mapping = Dictionary(uniqueKeysWithValues: defaults.map { ($0, $0) })
        defaults.forEach { target in
            if let match = bands.first(where: { $0.localizedCaseInsensitiveCompare(target) == .orderedSame }) {
                mapping[target] = match
            }
        }
        return mapping
    }

    private static func fnv1a(_ value: String) -> UInt32 {
        var hash: UInt32 = 0x811c9dc5
        for codeUnit in value.utf16 {
            hash ^= UInt32(codeUnit)
            hash = hash &* 0x01000193
        }
        return hash
    }
}

private struct VariantCandidate {
    var variant: AssembledVariant
    var component: Component
    var renderedText: String
}

private struct ComponentCandidate {
    var component: Component
    var renderedText: String
}

private struct GeneratedCandidate {
    var text: String
    var variantID: String
}

public func buildGenerationFingerprint(
    projectMetadata: ProjectMetadata,
    student: Student,
    result: AchievementResult,
    concreteSubject: String? = nil
) -> String {
    jsonObject([
        ("metadata", stableMetadata(projectMetadata)),
        ("student", stableStudent(student)),
        ("result", stableResult(result, concreteSubject: concreteSubject))
    ])
}

private func stableMetadata(_ metadata: ProjectMetadata) -> String {
    jsonObject([
        ("name", jsonString(metadata.name)),
        ("term", jsonString(metadata.term)),
        ("yearLevel", jsonString(metadata.yearLevel.rawValue)),
        ("useFirstNameOnly", jsonBool(metadata.useFirstNameOnly)),
        ("selectedSubjectOrder", jsonStringArray(selectedSubjectKeys(metadata.selectedSubjects))),
        ("reportLayout", stableReportLayout(metadata.reportLayout))
    ])
}

private func stableReportLayout(_ layout: ReportLayout?) -> String {
    let normalized = normalizeReportLayout(layout)
    return jsonObject([
        ("enabled", jsonBool(normalized.enabled)),
        ("order", jsonStringArray(normalized.order.map(\.rawValue))),
        ("include", jsonObject([
            ("general", jsonBool(normalized.include[.general] != false)),
            ("subject", jsonBool(normalized.include[.subject] != false)),
            ("dispositions", jsonBool(normalized.include[.dispositions] != false)),
            ("nextSteps", jsonBool(normalized.include[.nextSteps] != false))
        ]))
    ])
}

private func stableStudent(_ student: Student) -> String {
    jsonObject([
        ("id", jsonString(student.id)),
        ("firstName", jsonString(student.firstName)),
        ("lastName", jsonString(student.lastName)),
        ("gender", jsonString(student.gender?.rawValue ?? "")),
        ("pronouns", jsonString(student.pronouns ?? "")),
        ("yearLevel", jsonString(student.yearLevel.rawValue)),
        ("reportEmphasisNote", jsonString(student.reportEmphasisNote ?? "")),
        ("attitudeDescriptor", jsonString(student.attitudeDescriptor ?? ""))
    ])
}

private func stableResult(_ result: AchievementResult, concreteSubject: String?) -> String {
    var fields: [(String, String)] = [
        ("studentId", jsonString(result.studentId)),
        ("subject", jsonString(result.subject)),
        ("concreteSubject", jsonString(concreteSubject ?? "")),
        ("achievementLevel", jsonString(result.achievementLevel?.rawValue ?? "")),
        ("focusStrand", jsonString(result.focusStrand ?? "")),
        ("evidenceText", jsonString(result.evidenceText ?? ""))
    ]
    if let textType = normalizeReportContextFieldForFingerprint(result.textType) {
        fields.append(("textType", jsonString(textType)))
    }
    if let learningContext = normalizeReportContextFieldForFingerprint(result.learningContext) {
        fields.append(("learningContext", jsonString(learningContext)))
    }
    fields.append(contentsOf: [
        ("flags", stableFlags(result.flags)),
        ("reportEmphasisNote", jsonString(result.reportEmphasisNote ?? "")),
        ("englishFocusTags", jsonStringArray(stableOrderedArray(result.englishFocusTags))),
        ("mathProficiencies", jsonStringArray(stableOrderedArray(result.mathProficiencies))),
        ("mathMindsetToggles", jsonStringArray(stableOrderedArray(result.mathMindsetToggles))),
        ("nextStepGoals", jsonStringArray(stableOrderedArray(result.nextStepGoals)))
    ])
    return jsonObject(fields)
}

private func normalizeReportContextFieldForFingerprint(_ value: String?) -> String? {
    let normalized = (value ?? "")
        .replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"[.!?;:]+$"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return nil }
    let emptyMarkers = ["n/a", "na", "not applicable", "none", "null", "-", "\u{2014}"]
    return emptyMarkers.contains(normalized.lowercased()) ? nil : normalized
}

private func stableFlags(_ flags: [String: Bool]?) -> String {
    jsonObject((flags ?? [:])
        .filter { $0.value }
        .sorted { $0.key < $1.key }
        .map { (key, value) in (key, jsonBool(value)) })
}

private func stableOrderedArray(_ values: [String]?) -> [String] {
    (values ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
}

private func jsonObject(_ fields: [(String, String)]) -> String {
    "{\(fields.map { "\(jsonString($0.0)):\($0.1)" }.joined(separator: ","))}"
}

private func jsonStringArray(_ values: [String]) -> String {
    "[\(values.map(jsonString).joined(separator: ","))]"
}

private func jsonBool(_ value: Bool) -> String {
    value ? "true" : "false"
}

private func jsonString(_ value: String) -> String {
    var output = "\""
    for scalar in value.unicodeScalars {
        switch scalar.value {
        case 0x08:
            output += "\\b"
        case 0x09:
            output += "\\t"
        case 0x0A:
            output += "\\n"
        case 0x0C:
            output += "\\f"
        case 0x0D:
            output += "\\r"
        case 0x22:
            output += "\\\""
        case 0x5C:
            output += "\\\\"
        case 0x00..<0x20:
            output += "\\u" + String(format: "%04x", scalar.value)
        default:
            output.append(String(scalar))
        }
    }
    output += "\""
    return output
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
