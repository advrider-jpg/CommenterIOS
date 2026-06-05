import CommenterDomain
import CommenterReportSafety
import Foundation

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
enum FoundationModelReportGenerator {
    static func reviseDeterministicDraft(_ request: AIReportRevisionRequest) async throws -> AIReportRevisionResult {
        let builtPrompt = AIReportPromptBuilder.reviseDeterministicDraft(request)
        return try await revise(request, builtPrompt: builtPrompt, tracePrefix: "foundation")
    }

    static func adjustTone(_ request: AIReportRevisionRequest) async throws -> AIReportRevisionResult {
        let builtPrompt = AIReportPromptBuilder.adjustTone(request)
        return try await revise(request, builtPrompt: builtPrompt, tracePrefix: "foundation-tone")
    }

    private static func revise(
        _ request: AIReportRevisionRequest,
        builtPrompt: BuiltAIPrompt,
        tracePrefix: String
    ) async throws -> AIReportRevisionResult {
        let startedAt = nowMilliseconds()
        let inputFingerprint = stableTextFingerprint([builtPrompt.instructions, builtPrompt.prompt].joined(separator: "\n"))
        let session = LanguageModelSession(instructions: builtPrompt.instructions)
        let response = try await session.respond(
            to: builtPrompt.prompt,
            generating: FoundationReportRevisionOutput.self
        )
        let completedAt = nowMilliseconds()
        let output = response.content
        let validation = validateRevision(output.revisedText, request: request, validatedAt: completedAt)
        let outputFingerprint = stableTextFingerprint(output.revisedText)
        let trace = AIReportTrace(
            traceId: "\(tracePrefix)-\(startedAt)-\(outputFingerprint)",
            promptId: builtPrompt.descriptor.id,
            promptVersion: builtPrompt.descriptor.version,
            promptPurpose: builtPrompt.descriptor.purpose,
            modelAvailabilityAtStart: .available,
            startedAt: startedAt,
            completedAt: completedAt,
            inputFingerprint: inputFingerprint,
            deterministicDraftFingerprint: stableTextFingerprint(request.deterministicDraft),
            toneProfile: request.options.toneProfile,
            customInstructionFingerprint: request.options.customInstruction.map(stableTextFingerprint),
            outputFingerprint: outputFingerprint,
            validationSummary: validation,
            outcome: validation.status == .blocked ? .blockedByValidation : .completed
        )
        return AIReportRevisionResult(
            revisedText: output.revisedText,
            changeSummary: output.changeSummary,
            validation: validation,
            trace: trace,
            reviewWarnings: output.reviewWarnings
        )
    }

    static func draftFromEvidence(_ request: AIReportDraftRequest) async throws -> AIReportDraftResult {
        let builtPrompt = AIReportPromptBuilder.draftFromEvidence(request)
        let startedAt = nowMilliseconds()
        let inputFingerprint = stableTextFingerprint([builtPrompt.instructions, builtPrompt.prompt].joined(separator: "\n"))
        let session = LanguageModelSession(instructions: builtPrompt.instructions)
        let response = try await session.respond(
            to: builtPrompt.prompt,
            generating: FoundationReportDraftOutput.self
        )
        let completedAt = nowMilliseconds()
        let output = response.content
        let validation = validateDraft(output.draftText, request: request, validatedAt: completedAt)
        let outputFingerprint = stableTextFingerprint(output.draftText)
        let trace = AIReportTrace(
            traceId: "foundation-draft-\(startedAt)-\(outputFingerprint)",
            promptId: builtPrompt.descriptor.id,
            promptVersion: builtPrompt.descriptor.version,
            promptPurpose: builtPrompt.descriptor.purpose,
            modelAvailabilityAtStart: .available,
            startedAt: startedAt,
            completedAt: completedAt,
            inputFingerprint: inputFingerprint,
            deterministicDraftFingerprint: nil,
            toneProfile: request.options.toneProfile,
            customInstructionFingerprint: request.options.customInstruction.map(stableTextFingerprint),
            outputFingerprint: outputFingerprint,
            validationSummary: validation,
            outcome: validation.status == .blocked ? .blockedByValidation : .completed
        )
        return AIReportDraftResult(draftText: output.draftText, validation: validation, trace: trace)
    }

    static func critiqueReport(_ request: AIReportCritiqueRequest) async throws -> AIReportCritiqueResult {
        let builtPrompt = AIReportPromptBuilder.critiqueReport(request)
        let session = LanguageModelSession(instructions: builtPrompt.instructions)
        let response = try await session.respond(
            to: builtPrompt.prompt,
            generating: FoundationReportCritiqueOutput.self
        )
        let completedAt = nowMilliseconds()
        let validation = ReportSafetyValidator.validate(
            text: request.text,
            context: request.context.withValidatedAt(completedAt)
        )
        return AIReportCritiqueResult(
            validation: validation,
            reviewNotes: response.content.reviewNotes
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Teacher-review output for a revised school report")
private struct FoundationReportRevisionOutput: Equatable {
    @Guide(description: "Final revised report text only. Do not include headings, bullets, markdown, or process notes.")
    var revisedText: String

    @Guide(description: "One short sentence explaining the main writing changes.")
    var changeSummary: String

    @Guide(description: "Teacher review warnings, if any. Return an empty array when there are none.")
    var reviewWarnings: [String]
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Teacher-review output for a school report drafted from approved evidence")
private struct FoundationReportDraftOutput: Equatable {
    @Guide(description: "Draft report text grounded only in supplied evidence. Do not include headings, bullets, markdown, or process notes.")
    var draftText: String
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Teacher-review critique notes for a school report")
private struct FoundationReportCritiqueOutput: Equatable {
    @Guide(description: "Short teacher-facing review notes. Do not rewrite the report text.")
    var reviewNotes: [String]
}

private func nowMilliseconds() -> Int64 {
    Int64((Date().timeIntervalSince1970 * 1000).rounded())
}

private extension ReportValidationContext {
    func withValidatedAt(_ validatedAt: Int64) -> ReportValidationContext {
        ReportValidationContext(
            student: student,
            projectMetadata: projectMetadata,
            subject: subject,
            allowedFacts: allowedFacts,
            deterministicDraft: deterministicDraft,
            knownStudents: knownStudents,
            achievementLevel: achievementLevel,
            forbiddenMentions: forbiddenMentions,
            requiredMentions: requiredMentions,
            maximumCharacters: maximumCharacters,
            validatedAt: validatedAt
        )
    }
}
#endif
