import CommenterDomain
import Foundation

public enum ReportGenerationError: LocalizedError, Equatable {
    case invalidDataset([String])
    case missingAchievementLevel(studentName: String, subject: String)
    case unavailableSubject(String)
    case noEligibleComment(studentName: String, subject: String)
    case unresolvedPlaceholders(label: String, placeholders: [String])

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
        self.usedVariantIds = usedVariantIds.union(existingUsage.keys)
        self.usageCounts = existingUsage.filter { $0.value > 0 }
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
        let subjectResolution = resolveSubjectForGeneration(subject, data: data, focusStrand: result.focusStrand)
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

        trace.append("Request: \(subject); candidates: \(subjectResolution.candidates.joined(separator: ", ")); text subject: \(concreteSubject); level: \(student.yearLevel.rawValue) -> \(normalizedLevel); band: \(achievementLevel.rawValue) -> \(mappedBand)")

        let generated = findVariantCandidate(
            dataSubjects: subjectResolution.candidates,
            normalizedLevel: normalizedLevel,
            mappedBand: mappedBand,
            result: result,
            context: context,
            trace: &trace
        ) ?? assembleFromComponents(
            dataSubjects: subjectResolution.candidates,
            normalizedLevel: normalizedLevel,
            mappedBand: mappedBand,
            result: result,
            context: context,
            trace: &trace
        )

        guard let generated else {
            throw ReportGenerationError.noEligibleComment(studentName: context.displayName, subject: subject)
        }

        let finalText = cleanSpacing(generated.text)
        let unresolved = findUnresolvedPlaceholders(finalText)
        guard unresolved.isEmpty else {
            throw ReportGenerationError.unresolvedPlaceholders(label: "\(context.displayName) \(subject) report", placeholders: unresolved)
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
        for scalar in value.unicodeScalars {
            hash ^= UInt32(scalar.value)
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
    let payload: [String: Any] = [
        "metadata": stableMetadata(projectMetadata),
        "student": stableStudent(student),
        "result": stableResult(result, concreteSubject: concreteSubject)
    ]
    let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    return String(decoding: data, as: UTF8.self)
}

private func stableMetadata(_ metadata: ProjectMetadata) -> [String: Any] {
    [
        "name": metadata.name,
        "term": metadata.term,
        "yearLevel": metadata.yearLevel.rawValue,
        "useFirstNameOnly": metadata.useFirstNameOnly,
        "selectedSubjectOrder": selectedSubjectKeys(metadata.selectedSubjects),
        "reportLayout": stableReportLayout(metadata.reportLayout)
    ]
}

private func stableReportLayout(_ layout: ReportLayout?) -> [String: Any] {
    let normalized = normalizeReportLayout(layout)
    return [
        "enabled": normalized.enabled,
        "order": normalized.order.map(\.rawValue),
        "include": [
            "general": normalized.include[.general] != false,
            "subject": normalized.include[.subject] != false,
            "dispositions": normalized.include[.dispositions] != false,
            "nextSteps": normalized.include[.nextSteps] != false
        ]
    ]
}

private func stableStudent(_ student: Student) -> [String: Any] {
    [
        "id": student.id,
        "firstName": student.firstName,
        "lastName": student.lastName,
        "gender": student.gender?.rawValue ?? "",
        "pronouns": student.pronouns ?? "",
        "yearLevel": student.yearLevel.rawValue,
        "reportEmphasisNote": student.reportEmphasisNote ?? "",
        "attitudeDescriptor": student.attitudeDescriptor ?? ""
    ]
}

private func stableResult(_ result: AchievementResult, concreteSubject: String?) -> [String: Any] {
    var payload: [String: Any] = [
        "studentId": result.studentId,
        "subject": result.subject,
        "concreteSubject": concreteSubject ?? "",
        "achievementLevel": result.achievementLevel?.rawValue ?? "",
        "focusStrand": result.focusStrand ?? "",
        "evidenceText": result.evidenceText ?? "",
        "flags": stableFlags(result.flags),
        "reportEmphasisNote": result.reportEmphasisNote ?? "",
        "englishFocusTags": stableOrderedArray(result.englishFocusTags),
        "mathProficiencies": stableOrderedArray(result.mathProficiencies),
        "mathMindsetToggles": stableOrderedArray(result.mathMindsetToggles),
        "nextStepGoals": stableOrderedArray(result.nextStepGoals)
    ]
    if let textType = normalizeReportContextFieldForFingerprint(result.textType) {
        payload["textType"] = textType
    }
    if let learningContext = normalizeReportContextFieldForFingerprint(result.learningContext) {
        payload["learningContext"] = learningContext
    }
    return payload
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

private func stableFlags(_ flags: [String: Bool]?) -> [String: Bool] {
    Dictionary(uniqueKeysWithValues: (flags ?? [:]).filter { $0.value }.sorted { $0.key < $1.key })
}

private func stableOrderedArray(_ values: [String]?) -> [String] {
    (values ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
