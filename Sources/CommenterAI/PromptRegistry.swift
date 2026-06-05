import CommenterDomain
import Foundation

public struct AIPromptDescriptor: Codable, Equatable, Sendable {
    public var id: String
    public var version: String
    public var purpose: AIPromptPurpose

    public init(id: String, version: String, purpose: AIPromptPurpose) {
        self.id = id
        self.version = version
        self.purpose = purpose
    }
}

public enum AIPromptRegistry {
    public static let reviseDeterministicDraft = AIPromptDescriptor(
        id: "report.revise.deterministic.v1",
        version: "1.0.0",
        purpose: .reviseDeterministicDraft
    )

    public static let toneAdjustment = AIPromptDescriptor(
        id: "report.adjust.tone.v1",
        version: "1.0.0",
        purpose: .adjustTone
    )

    public static let draftFromEvidence = AIPromptDescriptor(
        id: "report.draft.evidence.v1",
        version: "1.0.0",
        purpose: .draftFromEvidence
    )

    public static let critiqueReport = AIPromptDescriptor(
        id: "report.critique.safety.v1",
        version: "1.0.0",
        purpose: .critiqueReport
    )

    public static let extractReportSafeFacts = AIPromptDescriptor(
        id: "facts.extract.reportSafe.v1",
        version: "1.0.0",
        purpose: .extractReportSafeFacts
    )
}

public struct BuiltAIPrompt: Equatable, Sendable {
    public var descriptor: AIPromptDescriptor
    public var instructions: String
    public var prompt: String

    public init(descriptor: AIPromptDescriptor, instructions: String, prompt: String) {
        self.descriptor = descriptor
        self.instructions = instructions
        self.prompt = prompt
    }
}

public enum AIReportPromptBuilder {
    public static func reviseDeterministicDraft(_ request: AIReportRevisionRequest) -> BuiltAIPrompt {
        let facts = reportSafeFacts(project: request.project, studentId: request.studentId, subject: request.subject)
        return BuiltAIPrompt(
            descriptor: AIPromptRegistry.reviseDeterministicDraft,
            instructions: sharedPolicy(options: request.options),
            prompt: [
                "Task: revise the deterministic draft for teacher review.",
                "Student: \(displayName(project: request.project, studentId: request.studentId))",
                "Subject: \(request.subject)",
                "Target length: \(request.options.targetLength.rawValue)",
                "Allowed report-safe facts:",
                facts.isEmpty ? "- None supplied beyond the deterministic draft." : facts.map { "- \($0.text)" }.joined(separator: "\n"),
                "Deterministic draft:",
                request.deterministicDraft,
                "Return improved report text, a short change summary, and review warnings. Do not mark it approved."
            ].joined(separator: "\n")
        )
    }

    public static func adjustTone(_ request: AIReportRevisionRequest) -> BuiltAIPrompt {
        BuiltAIPrompt(
            descriptor: AIPromptRegistry.toneAdjustment,
            instructions: sharedPolicy(options: request.options),
            prompt: [
                "Task: adjust only the tone of this teacher report for teacher review.",
                "Student: \(displayName(project: request.project, studentId: request.studentId))",
                "Subject: \(request.subject)",
                "Tone target:",
                request.options.toneProfile.promptInstructions.map { "- \($0)" }.joined(separator: "\n"),
                "Current report text:",
                request.deterministicDraft,
                "Return tone-adjusted report text, a short change summary, and review warnings. Preserve facts, achievement level, meaning, paragraph shape, and teacher intent."
            ].joined(separator: "\n")
        )
    }

    public static func critiqueReport(_ request: AIReportCritiqueRequest) -> BuiltAIPrompt {
        BuiltAIPrompt(
            descriptor: AIPromptRegistry.critiqueReport,
            instructions: sharedPolicy(options: AIReportOptions()),
            prompt: [
                "Task: critique this report for teacher review. Do not rewrite unless explicitly requested.",
                "Student: \(request.context.student.firstName)",
                "Subject: \(request.context.subject)",
                "Report text:",
                request.text,
                "Return safety, support, tone, and clarity findings."
            ].joined(separator: "\n")
        )
    }

    public static func draftFromEvidence(_ request: AIReportDraftRequest) -> BuiltAIPrompt {
        BuiltAIPrompt(
            descriptor: AIPromptRegistry.draftFromEvidence,
            instructions: sharedPolicy(options: request.options),
            prompt: [
                "Task: draft report text from approved evidence for teacher review.",
                "Student: \(displayName(project: request.project, studentId: request.studentId))",
                "Subject: \(request.subject)",
                "Approved evidence:",
                request.evidence.filter { $0.approvedForPrompt && $0.sensitivity == .reportSafe }.map { "- \($0.text)" }.joined(separator: "\n"),
                "Return draft text, a support summary, and review warnings. Do not mark it approved."
            ].joined(separator: "\n")
        )
    }
}

public extension AIToneProfile {
    var promptInstructions: [String] {
        [
            warmth.instruction(axis: "warmth"),
            specificity.instruction(axis: "specificity"),
            concision.instruction(axis: "concision"),
            formality.instruction(axis: "formality"),
            encouragement.instruction(axis: "encouragement"),
            nextStepDirectness.instruction(axis: "next-step directness"),
            evidenceAnchoring.instruction(axis: "evidence anchoring"),
            schoolVoice.instruction
        ]
    }
}

private extension ToneAxis {
    func instruction(axis: String) -> String {
        switch self {
        case .low:
            return "Keep \(axis) restrained."
        case .slightlyLow:
            return "Use slightly restrained \(axis)."
        case .balanced:
            return "Keep \(axis) balanced."
        case .slightlyHigh:
            return "Use slightly increased \(axis)."
        case .high:
            return "Use clearly increased \(axis), without exaggeration."
        }
    }
}

private extension SchoolVoice {
    var instruction: String {
        switch self {
        case .standard:
            return "Use clear standard school-report wording."
        case .warmPrimary:
            return "Use warm primary-school report wording while staying evidence-grounded."
        case .formalReport:
            return "Use formal report wording with precise, restrained phrasing."
        case .conciseSystem:
            return "Use concise report wording suitable for a constrained reporting system."
        case .strengthsBased:
            return "Use strengths-based wording while keeping next steps honest and specific."
        }
    }
}

private func sharedPolicy(options: AIReportOptions) -> String {
    ([
        "You revise school report comments for teacher review.",
        "Use only the deterministic draft and report-safe facts supplied by the app.",
        "Do not invent grades, behavior incidents, diagnoses, accommodations, family context, protected traits, rankings, or future guarantees.",
        "Do not mention AI, Apple, prompts, policies, or the generation process in report text.",
        "Do not use private teacher notes unless they are explicitly supplied as report-safe facts.",
        "The result is not export-ready until app validators pass and the teacher approves it."
    ] + options.toneProfile.promptInstructions
        + mentionPolicy(options)
        + customInstructionPolicy(options.customInstruction)
    ).joined(separator: "\n")
}

private func mentionPolicy(_ options: AIReportOptions) -> [String] {
    var lines: [String] = []
    let forbidden = cleanedMentionList(options.forbiddenMentions)
    if !forbidden.isEmpty {
        lines.append("Do not mention these teacher-provided details:")
        lines.append(contentsOf: forbidden.map { "- \($0)" })
    }
    let required = cleanedMentionList(options.requiredMentions)
    if !required.isEmpty {
        lines.append("Include these teacher-required details only if they fit naturally and remain report-safe:")
        lines.append(contentsOf: required.map { "- \($0)" })
    }
    return lines
}

private func customInstructionPolicy(_ instruction: String?) -> [String] {
    guard let instruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines), !instruction.isEmpty else {
        return []
    }
    return [
        "Teacher custom instruction, subordinate to all safety rules:",
        instruction
    ]
}

private func cleanedMentionList(_ mentions: [String]) -> [String] {
    Array(
        Set(mentions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    )
    .sorted()
}

private func reportSafeFacts(project: Project, studentId: String, subject: String) -> [ReportSafeFact] {
    project.results
        .filter { $0.studentId == studentId && $0.subject == subject }
        .flatMap { result -> [ReportSafeFact] in
            [
                result.evidenceText.map { ReportSafeFact(id: "evidence-\(stableTextFingerprint($0))", text: $0, source: .achievementResultEvidence) },
                result.learningContext.map { ReportSafeFact(id: "context-\(stableTextFingerprint($0))", text: $0, source: .learningContext) },
                result.reportEmphasisNote.map { ReportSafeFact(id: "note-\(stableTextFingerprint($0))", text: $0, source: .reportEmphasisNote) }
            ].compactMap { $0 }
        }
        .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

private func displayName(project: Project, studentId: String) -> String {
    guard let student = project.roster.first(where: { $0.id == studentId }) else {
        return "Student"
    }
    let first = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let last = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    return project.metadata.useFirstNameOnly ? (first.isEmpty ? full : first) : (full.isEmpty ? "Student" : full)
}
