import CommenterDomain
import Foundation

public enum ReportInputFeedbackTone: String, Equatable, Sendable {
    case error
    case warning
    case success
}

public struct ReportInputFeedback: Equatable, Sendable {
    public var tone: ReportInputFeedbackTone
    public var message: String
    public var detail: String?

    public init(tone: ReportInputFeedbackTone, message: String, detail: String? = nil) {
        self.tone = tone
        self.message = message
        self.detail = detail
    }
}

private let feedbackMaxReportContextFieldLength = 120
private let feedbackTemplateTokenPattern = #"\[[^\]]+\]|\{[^}]+\}"#
private let feedbackLeadingPronounPattern = #"^(he|she|they|i|we)\b"#
private let feedbackSubordinateClausePattern = #"^(because|when|while|although|if|as)\b"#
private let feedbackFiniteSentenceStartPattern = #"^(he|she|they|i|we|[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\s+(wrote|writes|created|creates|solved|solves|used|uses|explained|explains|described|describes|completed|completes|showed|shows|demonstrated|demonstrates|is|are|was|were|has|have)\b"#

public func reportContextPhraseFeedback(value: String?, label: String, example: String) -> ReportInputFeedback? {
    let raw = value ?? ""
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    let normalized = normalizeReportContextFieldForFeedback(raw)
    guard !normalized.isEmpty else { return nil }

    if raw.range(of: #"[\r\n]"#, options: .regularExpression) != nil {
        return ReportInputFeedback(tone: .error, message: "\(label) must be a short phrase, not multiple lines.")
    }
    if raw.range(of: feedbackTemplateTokenPattern, options: .regularExpression) != nil {
        return ReportInputFeedback(tone: .error, message: "\(label) must not contain template placeholders such as [context] or {Name}.")
    }
    if normalized.count > feedbackMaxReportContextFieldLength {
        return ReportInputFeedback(tone: .error, message: "\(label) must be \(feedbackMaxReportContextFieldLength) characters or fewer.")
    }
    if matchesFeedback(feedbackLeadingPronounPattern, normalized) || matchesFeedback(feedbackFiniteSentenceStartPattern, normalized) {
        return ReportInputFeedback(tone: .error, message: "\(label) starts like a sentence.", detail: "Use a short phrase instead, such as \"\(example)\".")
    }
    if matchesFeedback(feedbackSubordinateClausePattern, normalized) {
        return ReportInputFeedback(tone: .error, message: "\(label) starts like a clause that may not fit into a report sentence.", detail: "Use a compact phrase instead, such as \"\(example)\".")
    }
    return nil
}

public func evidenceInputFeedback(
    value: String?,
    student: Student,
    subject: String,
    result: AchievementResult,
    projectMetadata: ProjectMetadata
) -> ReportInputFeedback? {
    let raw = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    let context = repairContext(student: student, subject: subject, result: result, projectMetadata: projectMetadata)
    let repaired = repairEvidenceText(raw, context: context)
    if hasBlockingRepairIssue(repaired.issues) {
        return ReportInputFeedback(tone: .error, message: blockingRepairMessage(label: "Evidence", issues: repaired.issues))
    }
    if repaired.canUseAsSpecificTask, let phrase = repaired.specificTaskPhrase {
        return ReportInputFeedback(
            tone: .success,
            message: "This can be used as a short task phrase if a draft needs that detail.",
            detail: "Phrase checked: \"\(phrase)\"."
        )
    }
    if !repaired.sentences.isEmpty {
        return ReportInputFeedback(
            tone: .warning,
            message: "This reads as sentence-style evidence, so it will not be inserted into short phrase-only wording.",
            detail: "Standalone wording preview: \"\(truncateFeedbackPreview(repaired.appendedText))\"."
        )
    }
    return ReportInputFeedback(
        tone: .warning,
        message: "This evidence may be hard to use safely.",
        detail: "Use either a short task phrase or a complete sentence."
    )
}

public func reportNoteInputFeedback(
    value: String?,
    student: Student,
    subject: String,
    result: AchievementResult,
    projectMetadata: ProjectMetadata
) -> ReportInputFeedback? {
    let raw = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty else { return nil }
    let context = repairContext(student: student, subject: subject, result: result, projectMetadata: projectMetadata)
    let repaired = repairReportNoteText(raw, context: context)
    if hasBlockingRepairIssue(repaired.issues) {
        return ReportInputFeedback(tone: .error, message: blockingRepairMessage(label: "Report note", issues: repaired.issues))
    }
    let needsReview = repaired.units.contains { $0.kind == .gerundPhrase || $0.kind == .fragment }
    if needsReview {
        return ReportInputFeedback(
            tone: .warning,
            message: "This note can be checked, but it may need clearer report-ready wording.",
            detail: "Preview after wording check: \"\(truncateFeedbackPreview(repaired.text))\"."
        )
    }
    return ReportInputFeedback(
        tone: .success,
        message: "This note can be checked before it is added to a draft.",
        detail: repaired.text.isEmpty ? nil : "Preview after wording check: \"\(truncateFeedbackPreview(repaired.text))\"."
    )
}

private func repairContext(
    student: Student,
    subject: String,
    result: AchievementResult,
    projectMetadata: ProjectMetadata
) -> TeacherTextRepairContext {
    createTeacherTextRepairContext(
        student: student,
        placeholderContext: buildPlaceholderContext(student: student, subject: subject, result: result, projectMetadata: projectMetadata)
    )
}

private func normalizeReportContextFieldForFeedback(_ value: String) -> String {
    let normalized = value
        .replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"[.!?;:]+$"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let emptyMarkers = ["", "n/a", "na", "not applicable", "none", "null", "-", "\u{2014}"]
    return emptyMarkers.contains(normalized.lowercased()) ? "" : normalized
}

private func truncateFeedbackPreview(_ value: String, maxLength: Int = 150) -> String {
    let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count > maxLength else { return text }
    return "\(text.prefix(maxLength - 1))..."
}

private func matchesFeedback(_ pattern: String, _ value: String) -> Bool {
    value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}
