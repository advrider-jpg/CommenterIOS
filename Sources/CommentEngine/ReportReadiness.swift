import CommenterDomain
import Foundation

public enum ReportReadinessStatus: String, Codable, Equatable, Sendable {
    case missingStudent = "missing-student"
    case missingSubject = "missing-subject"
    case missingAchievementLevel = "missing-achievement-level"
    case missingConcreteFocus = "missing-concrete-focus"
    case missingReport = "missing-report"
    case unresolvedPlaceholder = "unresolved-placeholder"
    case languageQualityIssue = "language-quality-issue"
    case staleReport = "stale-report"
    case ready
    case lockedReady = "locked-ready"
    case lockedStale = "locked-stale"
    case autosaveBlocked = "autosave-blocked"
}

public struct ReportReadiness: Equatable, Sendable {
    public var status: ReportReadinessStatus
    public var studentId: String
    public var subject: String
    public var studentName: String
    public var message: String
    public var result: AchievementResult?
    public var report: GeneratedReport?
    public var placeholders: [String]

    public init(
        status: ReportReadinessStatus,
        studentId: String,
        subject: String,
        studentName: String,
        message: String,
        result: AchievementResult? = nil,
        report: GeneratedReport? = nil,
        placeholders: [String] = []
    ) {
        self.status = status
        self.studentId = studentId
        self.subject = subject
        self.studentName = studentName
        self.message = message
        self.result = result
        self.report = report
        self.placeholders = placeholders
    }
}

public struct ExpectedReportKey: Equatable, Sendable {
    public var student: Student
    public var subject: String
    public var result: AchievementResult?
    public var report: GeneratedReport?

    public init(student: Student, subject: String, result: AchievementResult?, report: GeneratedReport?) {
        self.student = student
        self.subject = subject
        self.result = result
        self.report = report
    }
}

public struct ProjectReadiness: Equatable, Sendable {
    public var expected: Int
    public var ready: Int
    public var blocked: [ReportReadiness]
    public var entries: [ReportReadiness]

    public init(expected: Int, ready: Int, blocked: [ReportReadiness], entries: [ReportReadiness]) {
        self.expected = expected
        self.ready = ready
        self.blocked = blocked
        self.entries = entries
    }
}

public struct ReportLanguageIssue: Equatable, Sendable {
    public enum Severity: String, Equatable, Sendable {
        case warning
        case error
    }

    public var code: String
    public var severity: Severity
    public var message: String
    public var excerpt: String?

    public init(code: String, severity: Severity, message: String, excerpt: String? = nil) {
        self.code = code
        self.severity = severity
        self.message = message
        self.excerpt = excerpt
    }
}

public struct ReportLanguageLintResult: Equatable, Sendable {
    public var issues: [ReportLanguageIssue]

    public init(issues: [ReportLanguageIssue]) {
        self.issues = issues
    }
}

public func getExpectedReportKeys(project: Project) -> [ExpectedReportKey] {
    project.roster.flatMap { student in
        selectedSubjectKeys(project.metadata.selectedSubjects).map { subject in
            ExpectedReportKey(
                student: student,
                subject: subject,
                result: project.results.first { $0.studentId == student.id && $0.subject == subject },
                report: project.reports.first { $0.studentId == student.id && $0.subject == subject }
            )
        }
    }
}

public func getResultReadiness(project: Project, studentId: String, subject: String) -> ReportReadiness {
    let student = project.roster.first { $0.id == studentId }
    let subjectExists = selectedSubjectKeys(project.metadata.selectedSubjects).contains(subject)
    let studentName = student.map { getDisplayName(student: $0, projectMetadata: project.metadata) } ?? "Unknown student"
    let result = project.results.first { $0.studentId == studentId && $0.subject == subject }

    guard student != nil else {
        return ReportReadiness(status: .missingStudent, studentId: studentId, subject: subject, studentName: studentName, message: "Student is missing.")
    }
    guard subjectExists else {
        return ReportReadiness(status: .missingSubject, studentId: studentId, subject: subject, studentName: studentName, message: "\(subject) is not selected.")
    }
    guard result?.achievementLevel != nil else {
        return ReportReadiness(status: .missingAchievementLevel, studentId: studentId, subject: subject, studentName: studentName, message: "\(studentName) needs an achievement level for \(subject).", result: result)
    }
    guard hasValidConcreteFocus(subject: subject, result: result) else {
        return ReportReadiness(status: .missingConcreteFocus, studentId: studentId, subject: subject, studentName: studentName, message: "\(studentName) needs the specific subject chosen for \(subject).", result: result)
    }

    return ReportReadiness(status: .ready, studentId: studentId, subject: subject, studentName: studentName, message: "\(studentName)'s \(subject) result is ready.", result: result)
}

public func getReportReadiness(project: Project, studentId: String, subject: String) -> ReportReadiness {
    let resultReadiness = getResultReadiness(project: project, studentId: studentId, subject: subject)
    guard resultReadiness.status == .ready else { return resultReadiness }

    guard let student = project.roster.first(where: { $0.id == studentId }),
          let result = resultReadiness.result
    else {
        return resultReadiness
    }

    let report = project.reports.first { $0.studentId == studentId && $0.subject == subject }
    let text = report?.manualEdit?.trimmedNonEmpty ?? report?.text.trimmedNonEmpty
    guard let report, let text else {
        return ReportReadiness(
            status: .missingReport,
            studentId: studentId,
            subject: subject,
            studentName: resultReadiness.studentName,
            message: "\(resultReadiness.studentName) needs a draft report for \(subject).",
            result: result,
            report: report
        )
    }

    let placeholders = findUnresolvedPlaceholders(text)
    guard placeholders.isEmpty else {
        return ReportReadiness(
            status: .unresolvedPlaceholder,
            studentId: studentId,
            subject: subject,
            studentName: resultReadiness.studentName,
            message: "\(resultReadiness.studentName)'s \(subject) draft contains template text that must be replaced.",
            result: result,
            report: report,
            placeholders: placeholders
        )
    }

    let placeholderContext = buildPlaceholderContext(student: student, subject: subject, result: result, projectMetadata: project.metadata)
    let languageLint = lintReportLanguage(
        text,
        displayName: placeholderContext.displayName,
        firstName: student.firstName,
        expectedSubjectPronoun: placeholderContext.heShe
    )
    if firstBlockingLanguageIssue(languageLint) != nil {
        return ReportReadiness(
            status: .languageQualityIssue,
            studentId: studentId,
            subject: subject,
            studentName: resultReadiness.studentName,
            message: "\(resultReadiness.studentName)'s \(subject) draft needs a language check before export.",
            result: result,
            report: report
        )
    }

    let expectedFingerprint = buildGenerationFingerprint(
        projectMetadata: project.metadata,
        student: student,
        result: result,
        concreteSubject: report.concreteSubject ?? subject
    )
    let stale = report.resultFingerprint != expectedFingerprint
    if stale {
        return ReportReadiness(
            status: report.isLocked ? .lockedStale : .staleReport,
            studentId: studentId,
            subject: subject,
            studentName: resultReadiness.studentName,
            message: "\(resultReadiness.studentName)'s \(subject) draft needs updating because the result or focus area changed.",
            result: result,
            report: report
        )
    }

    return ReportReadiness(
        status: report.isLocked ? .lockedReady : .ready,
        studentId: studentId,
        subject: subject,
        studentName: resultReadiness.studentName,
        message: "\(resultReadiness.studentName)'s \(subject) draft is ready for export.",
        result: result,
        report: report
    )
}

public func isReadyForExport(_ status: ReportReadinessStatus) -> Bool {
    status == .ready || status == .lockedReady
}

public func readinessLabel(_ status: ReportReadinessStatus) -> String {
    switch status {
    case .missingAchievementLevel:
        return "Needs result"
    case .missingConcreteFocus:
        return "Needs specific subject"
    case .missingReport:
        return "Needs draft"
    case .staleReport:
        return "Needs updating"
    case .lockedStale:
        return "Locked; needs updating"
    case .unresolvedPlaceholder:
        return "Contains template text"
    case .languageQualityIssue:
        return "Language check needed"
    case .ready:
        return "Ready"
    case .lockedReady:
        return "Ready (locked)"
    case .missingStudent:
        return "Missing student"
    case .missingSubject:
        return "Missing subject"
    case .autosaveBlocked:
        return "Save paused"
    }
}

public func getProjectReadiness(_ project: Project) -> ProjectReadiness {
    let entries = getExpectedReportKeys(project: project).map { key in
        getReportReadiness(project: project, studentId: key.student.id, subject: key.subject)
    }
    let ready = entries.filter { isReadyForExport($0.status) }.count
    return ProjectReadiness(
        expected: entries.count,
        ready: ready,
        blocked: entries.filter { !isReadyForExport($0.status) },
        entries: entries
    )
}

public func lintReportLanguage(
    _ text: String,
    displayName: String,
    firstName: String,
    expectedSubjectPronoun: String
) -> ReportLanguageLintResult {
    var issues: [ReportLanguageIssue] = findUnresolvedPlaceholders(text).map { placeholder in
        ReportLanguageIssue(
            code: "unresolved-placeholder",
            severity: .error,
            message: "The report contains template text that must be replaced.",
            excerpt: placeholder
        )
    }

    severeLanguagePatterns.forEach { pattern in
        if let match = firstMatch(pattern: pattern.pattern, in: text) {
            issues.append(ReportLanguageIssue(code: pattern.code, severity: .error, message: pattern.message, excerpt: match))
        }
    }

    let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedDisplayName.isEmpty {
        let escaped = NSRegularExpression.escapedPattern(for: trimmedDisplayName)
        if let repeated = firstMatch(pattern: #"(?:^|\s)("# + escaped + #"\s+"# + escaped + #")(?=\s|[.,!?;:]|$)"#, in: text, options: [.caseInsensitive]) {
            issues.append(ReportLanguageIssue(code: "repeated-display-name", severity: .error, message: "The student name appears twice in a row.", excerpt: repeated))
        }
    }

    return ReportLanguageLintResult(issues: issues)
}

public func firstBlockingLanguageIssue(_ result: ReportLanguageLintResult) -> ReportLanguageIssue? {
    result.issues.first { $0.severity == .error }
}

private func hasValidConcreteFocus(subject: String, result: AchievementResult?) -> Bool {
    guard subjectRequiresConcreteFocus(subject) else { return true }
    let focus = (result?.focusStrand ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !focus.isEmpty, focus != "none" else { return false }
    return getConcreteFocusOptions(subject).contains { $0.localizedCaseInsensitiveCompare(focus) == .orderedSame }
}

private struct SevereLanguagePattern {
    var code: String
    var pattern: String
    var message: String
}

private let severeLanguagePatterns: [SevereLanguagePattern] = [
    SevereLanguagePattern(code: "for-example-pronoun", pattern: #"For example,\s+(She|He|They)\b"#, message: "A report example begins with a pronoun and needs rewording."),
    SevereLanguagePattern(code: "repeated-name", pattern: #"\b([A-Z][a-z]+)\s+\1\b"#, message: "A student name appears twice in a row."),
    SevereLanguagePattern(code: "shown-name", pattern: #"has also shown\s+[A-Z][a-z]+\b"#, message: "A report note appears to have been wrapped around a full sentence."),
    SevereLanguagePattern(code: "shown-needs", pattern: #"has also shown\s+needs\b"#, message: "A growth note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "shown-has", pattern: #"has also shown\s+has\b"#, message: "A growth note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "shown-pronoun", pattern: #"has also shown\s+(she|he|they)\b"#, message: "A report note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "demonstrated-pronoun", pattern: #"demonstrated this during\s+(She|He|They)\b"#, message: "Evidence was inserted into a sentence frame incorrectly.")
]

private func firstMatch(
    pattern: String,
    in text: String,
    options: NSRegularExpression.Options = []
) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let matchRange = Range(match.range, in: text)
    else {
        return nil
    }
    return String(text[matchRange]).trimmingCharacters(in: .whitespacesAndNewlines)
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
