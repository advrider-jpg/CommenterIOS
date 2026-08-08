import CommenterDomain
import Foundation

public enum ReportGenerationError: LocalizedError, Equatable {
    case invalidDataset([String])
    case missingAchievementLevel(studentName: String, subject: String)
    case mismatchedResult
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
        case .mismatchedResult:
            return "The selected result does not belong to this student and subject. Reopen the project before creating draft comments."
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
    private let blockedVariantIds: Set<String>
    private var blockedReportTexts: Set<String>
    private var usageCounts: [String: Int]
    private let bandMapping: [String: String]
    private let datasetSubjects: [String]
    private let maxUsagePerClass: Int
    private let minVariantDistance: Int
    private let componentIndex: [String: Component]
    private let variantOrder: [String: Int]

    public init(
        data: CommentEngineData,
        projectMetadata: ProjectMetadata,
        usedVariantIds: Set<String> = [],
        existingUsage: [String: Int] = [:],
        blockedVariantIds: Set<String> = [],
        blockedReportTexts: Set<String> = []
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
        self.blockedVariantIds = blockedVariantIds
        self.blockedReportTexts = Set(blockedReportTexts.map(Self.normalizedReportText).filter { !$0.isEmpty })
        self.usageCounts = positiveUsage
        self.bandMapping = projectMetadata.bandMapping ?? Self.detectBandMapping(data)
        self.datasetSubjects = getDatasetSubjects(data)
        self.maxUsagePerClass = Self.uniquenessNumber(data, keys: ["MaxUsagePerClass", "MaxUsage"], defaultValue: Int.max)
        self.minVariantDistance = Self.uniquenessNumber(data, keys: ["MinVariantDistance"], defaultValue: 0)
        self.componentIndex = data.componentBank.reduce(into: [:]) { index, component in
            if index[component.keyID] == nil {
                index[component.keyID] = component
            }
        }
        self.variantOrder = data.assembledVariants.enumerated().reduce(into: [:]) { index, entry in
            if index[entry.element.variantID] == nil {
                index[entry.element.variantID] = entry.offset
            }
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
        guard result.studentId == student.id, result.subject == subject else {
            throw ReportGenerationError.mismatchedResult
        }
        try validateReportContextInputs(result)

        let mappedBand = bandMapping[achievementLevel.rawValue] ?? achievementLevel.rawValue
        let normalizedLevel = Self.normalizeLevel(student.yearLevel.rawValue)
        let subjectResolution = resolveSubjectForGeneration(
            uiSubject: subject,
            datasetSubjects: datasetSubjects,
            focusStrand: result.focusStrand
        )
        guard subjectResolution.eligible, !subjectResolution.candidates.isEmpty else {
            throw ReportGenerationError.unavailableSubject(subjectResolution.reason ?? "Draft comments are not available for \(subject) yet.")
        }

        let concreteSubject = subjectResolution.selectedDataSubject ?? subjectResolution.candidates[0]
        let requestedFocus = (result.focusStrand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let focusSelectsConcreteSubject = normalizeSubjectLabel(requestedFocus) == normalizeSubjectLabel(concreteSubject)
        let wordingFocus = subjectRequiresConcreteFocus(subject)
            || requestedFocus.lowercased() == "none"
            || focusSelectsConcreteSubject
            ? nil
            : requestedFocus
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

        let variantCandidates = findVariantCandidates(
            uiSubject: subject,
            dataSubjects: subjectResolution.candidates,
            normalizedLevel: normalizedLevel,
            mappedBand: mappedBand,
            learningFocus: wordingFocus,
            context: generationContext,
            trace: &trace
        )

        var generated: GeneratedCandidate?
        var finalText = ""
        var rejectedLanguageCandidates = 0
        for candidate in variantCandidates {
            var candidateTrace = trace
            let candidateText = try finalizeReportText(
                candidate.text,
                student: student,
                requestSubject: subject,
                concreteSubject: concreteSubject,
                result: result,
                context: generationContext,
                repairContext: repairContext,
                repairedEvidence: repairedEvidence,
                trace: &candidateTrace
            )
            if hasBlockingLanguageIssue(candidateText, student: student, context: generationContext) {
                rejectedLanguageCandidates += 1
                continue
            }
            if isBlockedReportText(candidateText) {
                candidateTrace.append("Rejected because the wording matches the current draft.")
                continue
            }
            generated = candidate
            finalText = candidateText
            trace = candidateTrace
            break
        }

        if generated == nil {
            let layout = normalizeReportLayout(projectMetadata.reportLayout)
            let useSeparateNextSteps = layout.include[.nextSteps] != false && !stableOrderedArray(result.nextStepGoals).isEmpty
            guard let assembled = assembleFromComponents(
                uiSubject: subject,
                dataSubjects: subjectResolution.candidates,
                normalizedLevel: normalizedLevel,
                mappedBand: mappedBand,
                learningFocus: wordingFocus,
                context: generationContext,
                includeNextStepComponent: !useSeparateNextSteps,
                trace: &trace
            ) else {
                if let wordingFocus, !wordingFocus.isEmpty {
                    throw ReportGenerationError.unavailableSubject(
                        "Draft comments could not be created for \(generationContext.displayName) in \(subject) because no saved wording matches the learning focus \"\(wordingFocus)\". Choose a different learning focus or clear it, then try again."
                    )
                }
                throw ReportGenerationError.noEligibleComment(studentName: generationContext.displayName, subject: subject)
            }
            let assembledText = try finalizeReportText(
                assembled.text,
                student: student,
                requestSubject: subject,
                concreteSubject: concreteSubject,
                result: result,
                context: generationContext,
                repairContext: repairContext,
                repairedEvidence: repairedEvidence,
                trace: &trace
            )
            guard !hasBlockingLanguageIssue(assembledText, student: student, context: generationContext),
                  !isBlockedReportText(assembledText)
            else {
                throw ReportGenerationError.noEligibleComment(studentName: generationContext.displayName, subject: subject)
            }
            generated = assembled
            finalText = assembledText
        }

        if rejectedLanguageCandidates > 0 {
            trace.append("Rejected by local language checks: \(rejectedLanguageCandidates)")
        }
        guard let generated else {
            throw ReportGenerationError.noEligibleComment(studentName: generationContext.displayName, subject: subject)
        }
        recordUsage(generated.variantID, reportText: finalText)

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

    private func findVariantCandidates(
        uiSubject: String,
        dataSubjects: [String],
        normalizedLevel: String,
        mappedBand: String,
        learningFocus: String?,
        context: PlaceholderContext,
        trace: inout [String]
    ) -> [GeneratedCandidate] {
        let normalizedSubjects = Set(dataSubjects.map(normalizeSubjectLabel))
        let hasFocus = !(learningFocus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            if hasFocus, componentStrandMatchesLearningFocus(
                uiSubject: uiSubject,
                learningFocus: learningFocus,
                componentStrand: component.strand
            ) {
                focusCandidates.append(candidate)
            }
        }

        trace.append("Variant subject matches: \(subjectMatchCount)")
        trace.append("Variant level matches: \(levelMatchCount)")
        trace.append("Variant band matches: \(bandMatchCount)")
        trace.append("Rejected by placeholders/context: \(placeholderRejected)")
        trace.append("Rejected by uniqueness: \(uniquenessRejected)")

        let pool = hasFocus ? focusCandidates : allCandidates
        if !focusCandidates.isEmpty {
            trace.append("Focus matched: \(learningFocus ?? "")")
        }
        return sortVariantsByPreference(pool).map {
            GeneratedCandidate(text: $0.renderedText, variantID: $0.variant.variantID)
        }
    }

    private func assembleFromComponents(
        uiSubject: String,
        dataSubjects: [String],
        normalizedLevel: String,
        mappedBand: String,
        learningFocus: String?,
        context: PlaceholderContext,
        includeNextStepComponent: Bool,
        trace: inout [String]
    ) -> GeneratedCandidate? {
        let normalizedSubjects = Set(dataSubjects.map(normalizeSubjectLabel))
        let hasFocus = !(learningFocus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            let focused = hasFocus ? eligible.filter {
                componentStrandMatchesLearningFocus(
                    uiSubject: uiSubject,
                    learningFocus: learningFocus,
                    componentStrand: $0.component.strand
                )
            } : []
            return (hasFocus ? focused : eligible).sorted { $0.component.keyID < $1.component.keyID }
        }

        guard let strength = components(type: .strength).first else {
            trace.append("Component assembly unavailable: missing eligible Strength component.")
            return nil
        }

        let evidence = components(type: .evidence).first
        let nextStep = includeNextStepComponent ? components(type: .nextStep).first : nil
        if includeNextStepComponent, nextStep == nil {
            trace.append("Component assembly unavailable: missing eligible NextStep component.")
            return nil
        }
        let sourceIds = [strength.component.keyID, evidence?.component.keyID, nextStep?.component.keyID].compactMap { $0 }
        let slots = recipeSlots(strength: strength, evidence: evidence, nextStep: nextStep)

        for recipe in data.recipeBank {
            let rendered = renderRecipe(recipe: recipe, slots: slots, context: context)
            if rendered.ok {
                guard canUseVariant(rendered.recipeID) else {
                    trace.append("Recipe \(rendered.sourceRecipeID) blocked by uniqueness rules.")
                    continue
                }
                trace.append("Assembled comment with recipe \(rendered.sourceRecipeID).")
                return GeneratedCandidate(text: rendered.text, variantID: rendered.recipeID)
            }
            trace.append("Recipe \(rendered.sourceRecipeID.ifEmpty(recipe.recipeID)) rejected: \(rendered.errors.prefix(2).joined(separator: " "))")
        }

        let parts = [strength.renderedText, evidence?.renderedText, nextStep?.renderedText]
            .compactMap { $0?.trimmedNonEmpty }
            .map(Self.ensureSentence)
        let variantID = recipeSyntheticVariantID(recipeID: "LOCAL_SENTENCE_JOIN", componentIDs: sourceIds)

        guard canUseVariant(variantID) else {
            trace.append("Component assembly blocked by uniqueness rules.")
            return nil
        }

        trace.append("Assembled comment with local sentence recipe fallback.")
        return GeneratedCandidate(text: cleanSpacing(parts.joined(separator: " ")), variantID: variantID)
    }

    private func recipeSlots(
        strength: ComponentCandidate,
        evidence: ComponentCandidate?,
        nextStep: ComponentCandidate?
    ) -> [RecipeComponentType: RenderedRecipeSlot] {
        var slots: [RecipeComponentType: RenderedRecipeSlot] = [
            .strength: RenderedRecipeSlot(type: .strength, component: strength.component, renderedText: strength.renderedText)
        ]
        if let evidence {
            slots[.evidence] = RenderedRecipeSlot(type: .evidence, component: evidence.component, renderedText: evidence.renderedText)
        }
        if let nextStep {
            slots[.nextStep] = RenderedRecipeSlot(type: .nextStep, component: nextStep.component, renderedText: nextStep.renderedText)
        }
        return slots
    }

    private func sortVariantsByPreference(_ variants: [VariantCandidate]) -> [VariantCandidate] {
        variants.sorted { left, right in
            let leftCount = usageCounts[left.variant.variantID] ?? 0
            let rightCount = usageCounts[right.variant.variantID] ?? 0
            if leftCount != rightCount { return leftCount < rightCount }
            let leftOrder = variantOrder[left.variant.variantID] ?? Int.max
            let rightOrder = variantOrder[right.variant.variantID] ?? Int.max
            if leftOrder != rightOrder { return leftOrder < rightOrder }
            return left.variant.variantID < right.variant.variantID
        }
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

        let contextSentence = generateReportContextSentence(subjectText: subjectText, context: context)
        if !contextSentence.isEmpty {
            trace.append("Teacher report context included.")
            subjectText = "\(Self.ensureSentence(subjectText)) \(contextSentence)"
        }

        let normalizedSubject = normalizeSubjectLabel(subject)
        if normalizedSubject == "english", let englishFocus = generateEnglishFocusSentence(student: student, subject: subject, result: result, displayName: context.displayName, pronouns: context) {
            subjectText = "\(Self.ensureSentence(subjectText)) \(englishFocus)"
        } else if normalizedSubject == "mathematics", let mathProficiency = generateMathProficiencySentence(student: student, subject: subject, result: result, displayName: context.displayName, pronouns: context) {
            subjectText = "\(Self.ensureSentence(subjectText)) \(mathProficiency)"
        }

        let noteSentence = try generateResultNoteSentence(result: result, repairContext: repairContext)
        if !noteSentence.isEmpty {
            trace.append("Result report emphasis included.")
            subjectText = "\(Self.ensureSentence(subjectText)) \(noteSentence)"
        }
        return cleanSpacing(subjectText)
    }

    private func finalizeReportText(
        _ baseText: String,
        student: Student,
        requestSubject: String,
        concreteSubject: String,
        result: AchievementResult,
        context: PlaceholderContext,
        repairContext: TeacherTextRepairContext,
        repairedEvidence: RepairedEvidenceText,
        trace: inout [String]
    ) throws -> String {
        let subjectText = try decorateSubjectText(
            baseText,
            student: student,
            subject: concreteSubject,
            result: result,
            context: context,
            repairContext: repairContext,
            repairedEvidence: repairedEvidence,
            trace: &trace
        )
        let rawText = try applyReportLayout(
            subjectText,
            student: student,
            subject: concreteSubject,
            result: result,
            context: context,
            repairContext: repairContext,
            trace: &trace
        )
        let finalText = normalizeSentenceCase(
            rawText,
            displayName: context.displayName,
            protectedTerms: [context.subject]
        )
        let unresolved = findUnresolvedPlaceholders(finalText)
        guard unresolved.isEmpty else {
            throw ReportGenerationError.unresolvedPlaceholders(
                label: "\(context.displayName) \(requestSubject) report",
                placeholders: unresolved
            )
        }
        return finalText
    }

    private func hasBlockingLanguageIssue(_ text: String, student: Student, context: PlaceholderContext) -> Bool {
        firstBlockingLanguageIssue(
            lintReportLanguage(
                text,
                displayName: context.displayName,
                firstName: student.firstName,
                expectedSubjectPronoun: context.heShe
            )
        ) != nil
    }

    private func isBlockedReportText(_ text: String) -> Bool {
        blockedReportTexts.contains(Self.normalizedReportText(text))
    }

    private static func normalizedReportText(_ text: String) -> String {
        cleanSpacing(text).lowercased()
    }

    private func applyReportLayout(
        _ subjectText: String,
        student: Student,
        subject: String,
        result: AchievementResult,
        context: PlaceholderContext,
        repairContext: TeacherTextRepairContext,
        trace: inout [String]
    ) throws -> String {
        let reportLayout = normalizeReportLayout(projectMetadata.reportLayout)

        var paragraphs: [ReportSection: String] = [.subject: subjectText]
        if reportLayout.include[.general] != false {
            paragraphs[.general] = try generateGeneralParagraph(
                student: student,
                subject: subject,
                displayName: context.displayName,
                repairContext: repairContext,
                trace: &trace
            )
        }
        if reportLayout.include[.dispositions] != false {
            paragraphs[.dispositions] = generateDispositionsParagraph(
                student: student,
                subject: subject,
                result: result,
                displayName: context.displayName
            )
        }
        if reportLayout.include[.nextSteps] != false {
            paragraphs[.nextSteps] = generateNextStepsParagraph(
                student: student,
                subject: subject,
                result: result,
                displayName: context.displayName
            )
        }

        let selected = reportLayout.order
            .filter { reportLayout.include[$0] != false }
            .compactMap { paragraphs[$0]?.trimmingCharacters(in: .whitespacesAndNewlines).trimmedNonEmpty }
        if !reportLayout.enabled {
            return cleanSpacing(selected.joined(separator: " "))
        }
        return selected.joined(separator: "\n\n")
    }

    private func generateGeneralParagraph(
        student: Student,
        subject: String,
        displayName: String,
        repairContext: TeacherTextRepairContext,
        trace: inout [String]
    ) throws -> String {
        var sentences: [String] = []
        if let attitude = student.attitudeDescriptor?.trimmedNonEmpty {
            let templates = [
                "{Name} is a {attitude} learner who approaches {Subject} with enthusiasm.",
                "A {attitude} learner, {Name} engages positively with {Subject} content.",
                "{Name} approaches learning in a {attitude} manner and participates actively in {Subject}."
            ]
            let hash = Self.fnv1a("\(student.id)::\(subject)::\(projectMetadata.id)::general")
            sentences.append(
                templates[Int(hash % UInt32(templates.count))]
                    .replacingOccurrences(of: "{Name}", with: displayName)
                    .replacingOccurrences(of: "{attitude}", with: attitude)
                    .replacingOccurrences(of: "{Subject}", with: subject)
            )
        }

        let note = try sanitizeNote(student.reportEmphasisNote, label: "Student report emphasis note")
        if !note.isEmpty {
            let repaired = repairReportNoteText(note, context: repairContext)
            if hasBlockingRepairIssue(repaired.issues) {
                throw ReportGenerationError.unsafeTeacherText(
                    label: "Student report emphasis note",
                    message: blockingRepairMessage(label: "Student report emphasis note", issues: repaired.issues)
                )
            }
            if !repaired.text.isEmpty {
                trace.append("Student report emphasis included.")
                sentences.append(repaired.text)
            }
        }
        return cleanSpacing(sentences.joined(separator: " "))
    }

    private func generateEnglishFocusSentence(student: Student, subject: String, result: AchievementResult, displayName: String, pronouns: PlaceholderContext) -> String? {
        let tags = stableOrderedArray(result.englishFocusTags)
        guard !tags.isEmpty else { return nil }
        if tags.count > 2 {
            return "\(displayName) has shown strength in \(formatList(tags))."
        }
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
        if proficiencies.count > 2 {
            return "\(displayName) demonstrates strength in \(formatList(proficiencies))."
        }
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

    private func generateDispositionsParagraph(
        student: Student,
        subject: String,
        result: AchievementResult,
        displayName: String
    ) -> String {
        let flagText = generateFlagParagraph(
            flags: result.flags,
            student: student,
            subject: subject,
            displayName: displayName
        )
        let fragments = stableOrderedArray(result.mathMindsetToggles).map(mindsetToFragment)
        let mindsetText: String
        if fragments.isEmpty {
            mindsetText = ""
        } else if fragments.count == 1 {
            mindsetText = "\(displayName) \(fragments[0])."
        } else if fragments.count == 2 {
            mindsetText = "\(displayName) \(fragments[0]) and \(fragments[1])."
        } else {
            let last = fragments[fragments.count - 1]
            mindsetText = "\(displayName) \(fragments.dropLast().joined(separator: ", ")), and \(last)."
        }
        return cleanSpacing([flagText, mindsetText].filter { !$0.isEmpty }.joined(separator: " "))
    }

    private func generateNextStepsParagraph(student: Student, subject: String, result: AchievementResult, displayName: String) -> String {
        let goals = stableOrderedArray(result.nextStepGoals)
            .map(formatNextStepGoalForReport)
            .filter { !$0.isEmpty }
        guard !goals.isEmpty else { return "" }
        if goals.count > 2 {
            return "Next steps for \(displayName) are to \(goals.dropLast().joined(separator: ", to ")), and to \(goals[goals.count - 1])."
        }
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

    private func generateReportContextSentence(subjectText: String, context: PlaceholderContext) -> String {
        let textType = cleanSpacing(context.textType ?? "")
        let learningContext = cleanSpacing(context.context ?? "")
        let textTypeNeeded = !textType.isEmpty && !includesPhrase(subjectText, phrase: textType)
        let learningContextNeeded = !learningContext.isEmpty && !includesPhrase(subjectText, phrase: learningContext)

        if !textTypeNeeded, !learningContextNeeded { return "" }
        if textTypeNeeded, learningContextNeeded {
            return "This was demonstrated through \(textType) \(learningContextPhrase(learningContext))."
        }
        if textTypeNeeded {
            return "This was demonstrated through \(textType)."
        }
        return "This was demonstrated \(learningContextPhrase(learningContext))."
    }

    private func learningContextPhrase(_ value: String) -> String {
        let phrase = cleanSpacing(value)
        if phrase.range(of: #"^(during|in|through|with|on|for|while|as part of)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
            return phrase
        }
        return "in \(phrase)"
    }

    private func includesPhrase(_ text: String, phrase: String) -> Bool {
        !phrase.isEmpty && text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private func formatList(_ items: [String]) -> String {
        if items.count <= 1 { return items.first ?? "" }
        if items.count == 2 { return "\(items[0]) and \(items[1])" }
        return "\(items.dropLast().joined(separator: ", ")), and \(items[items.count - 1])"
    }

    private func sanitizeNote(_ value: String?, label: String) throws -> String {
        let trimmed = cleanSpacing((value ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        if trimmed.isEmpty { return "" }
        if !findUnresolvedPlaceholders(trimmed).isEmpty {
            throw ReportGenerationError.unsafeTeacherText(label: label, message: "still contains template text that must be replaced.")
        }
        if trimmed.utf16.count > 180 {
            throw ReportGenerationError.unsafeTeacherText(label: label, message: "must be 180 characters or fewer before generation.")
        }
        return trimmed
    }

    private func validateReportContextInputs(_ result: AchievementResult) throws {
        if let feedback = reportContextPhraseFeedback(value: result.textType, label: "Text type / genre", example: "persuasive paragraph"),
           feedback.tone == .error {
            throw ReportGenerationError.unsafeTeacherText(label: "Text type / genre", message: feedback.message)
        }
        if let feedback = reportContextPhraseFeedback(value: result.learningContext, label: "Learning context / activity", example: "class novel discussion"),
           feedback.tone == .error {
            throw ReportGenerationError.unsafeTeacherText(label: "Learning context / activity", message: feedback.message)
        }
    }

    private func generateResultNoteSentence(result: AchievementResult, repairContext: TeacherTextRepairContext) throws -> String {
        let note = try sanitizeNote(result.reportEmphasisNote, label: "Result report emphasis note")
        guard !note.isEmpty else { return "" }
        let repaired = repairReportNoteText(note, context: repairContext)
        if hasBlockingRepairIssue(repaired.issues) {
            throw ReportGenerationError.unsafeTeacherText(
                label: "Result report emphasis note",
                message: blockingRepairMessage(label: "Result report emphasis note", issues: repaired.issues)
            )
        }
        return repaired.text
    }

    private func generateFlagParagraph(flags: [String: Bool]?, student: Student, subject: String, displayName: String) -> String {
        guard let flags else { return "" }
        var sentences: [String] = []
        reportFlags.forEach { flag in
            guard flags[flag.id] == true else { return }
            let hash = Self.fnv1a("\(student.id)::\(subject)::\(flag.id)")
            let sentence = flag.sentences[Int(hash % UInt32(flag.sentences.count))]
                .replacingOccurrences(of: "[StudentName]", with: displayName)
                .replacingOccurrences(of: "[Student Name]", with: displayName)
                .replacingOccurrences(of: "[Subject]", with: subject)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sentence.isEmpty else { return }
            sentences.append(sentence)
        }
        return cleanSpacing(sentences.joined(separator: " "))
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
        if blockedVariantIds.contains(variantID) { return false }
        let current = usageCounts[variantID] ?? 0
        if current >= maxUsagePerClass { return false }
        if minVariantDistance <= 0 || usedVariantIds.isEmpty { return true }

        guard let order = variantOrder[variantID] else { return true }
        for usedID in usedVariantIds {
            guard let usedOrder = variantOrder[usedID] else { continue }
            if abs(order - usedOrder) < minVariantDistance {
                return false
            }
        }
        return true
    }

    private mutating func recordUsage(_ variantID: String, reportText: String) {
        usageCounts[variantID, default: 0] += 1
        usedVariantIds.insert(variantID)
        let normalizedText = Self.normalizedReportText(reportText)
        if !normalizedText.isEmpty {
            blockedReportTexts.insert(normalizedText)
        }
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

    private static func ensureSentence(_ value: String) -> String {
        let text = cleanSpacing(value)
        return text.range(of: #"[.!?]$"#, options: .regularExpression) == nil ? "\(text)." : text
    }

    private static func uniquenessNumber(_ data: CommentEngineData, keys: [String], defaultValue: Int) -> Int {
        let normalizedKeys = Set(keys.map { $0.lowercased() })
        if let rule = data.uniquenessGuard.first(where: { normalizedKeys.contains($0.rule.lowercased()) }),
           rule.value.isFinite,
           rule.value >= 1,
           rule.value < Double(Int.max) {
            return Int(rule.value.rounded(.down))
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
        ("useFirstNameOnly", jsonBool(metadata.useFirstNameOnly)),
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

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
