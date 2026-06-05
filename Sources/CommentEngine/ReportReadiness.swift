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
    case aiNeedsReview = "ai-needs-review"
    case aiValidationBlocked = "ai-validation-blocked"
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

    public enum Source: String, Equatable, Sendable {
        case placeholder
        case customRule = "custom-rule"
        case retext
        case sourceCorpus = "source-corpus"
        case teacherText = "teacher-text"
    }

    public var code: String
    public var severity: Severity
    public var message: String
    public var excerpt: String?
    public var suggestion: String?
    public var source: Source?

    public init(
        code: String,
        severity: Severity,
        message: String,
        excerpt: String? = nil,
        suggestion: String? = nil,
        source: Source? = nil
    ) {
        self.code = code
        self.severity = severity
        self.message = message
        self.excerpt = excerpt
        self.suggestion = suggestion
        self.source = source
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
    let text = report.map { report in
        report.manualEdit ?? report.text
    }
    guard let report, let text, text.trimmedNonEmpty != nil else {
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

    if report.requiresTeacherApprovalForExport {
        if report.lastValidation?.status == .blocked {
            return ReportReadiness(
                status: .aiValidationBlocked,
                studentId: studentId,
                subject: subject,
                studentName: resultReadiness.studentName,
                message: "\(resultReadiness.studentName)'s \(subject) AI draft is blocked by validation and needs teacher correction.",
                result: result,
                report: report
            )
        }
        let currentFingerprint = stableTextFingerprint(text)
        guard report.reviewState?.status == .approved,
              report.reviewState?.approvalFingerprint == currentFingerprint,
              report.approvedTextFingerprint == currentFingerprint
        else {
            return ReportReadiness(
                status: .aiNeedsReview,
                studentId: studentId,
                subject: subject,
                studentName: resultReadiness.studentName,
                message: "\(resultReadiness.studentName)'s \(subject) AI draft needs teacher review and approval before export.",
                result: result,
                report: report
            )
        }
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
    case .aiNeedsReview:
        return "AI review needed"
    case .aiValidationBlocked:
        return "AI validation blocked"
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

public extension GeneratedReport {
    var exportText: String {
        manualEdit?.isEmpty == false ? manualEdit ?? "" : text
    }

    var requiresTeacherApprovalForExport: Bool {
        switch effectiveGenerationMode {
        case .aiPolishedDeterministic, .aiToneAdjusted, .aiDraftFromEvidence, .hybrid:
            return true
        case .deterministic, .manuallyEdited:
            return aiTrace != nil
        }
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
    expectedSubjectPronoun: String,
    allowWarnings: Bool = true
) -> ReportLanguageLintResult {
    var issues: [ReportLanguageIssue] = findUnresolvedPlaceholders(text).map { placeholder in
        ReportLanguageIssue(
            code: "unresolved-placeholder",
            severity: .error,
            message: "The report contains template text that must be replaced.",
            excerpt: placeholder,
            suggestion: "Replace the template token with real report text.",
            source: .placeholder
        )
    }

    let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmedDisplayName.isEmpty, trimmedDisplayName.lowercased() != trimmedFirstName.lowercased() {
        let escaped = NSRegularExpression.escapedPattern(for: trimmedDisplayName)
        if let repeated = firstMatch(pattern: #"(?:^|\s)("# + escaped + #"\s+"# + escaped + #")(?=\s|[.,!?;:]|$)"#, in: text, options: [.caseInsensitive]) {
            issues.append(ReportLanguageIssue(code: "repeated-display-name", severity: .error, message: "The student name appears twice in a row.", excerpt: repeated, suggestion: "Remove the duplicated name.", source: .customRule))
        }
    }

    if !trimmedFirstName.isEmpty {
        let escaped = NSRegularExpression.escapedPattern(for: trimmedFirstName)
        if let repeated = firstMatch(pattern: #"(?:^|\s)("# + escaped + #"\s+"# + escaped + #")(?=\s|[.,!?;:]|$)"#, in: text, options: [.caseInsensitive]) {
            issues.append(ReportLanguageIssue(code: "repeated-first-name", severity: .error, message: "The student first name appears twice in a row.", excerpt: repeated, suggestion: "Remove the duplicated name.", source: .customRule))
        }
    }

    severeLanguagePatterns.forEach { pattern in
        let options: NSRegularExpression.Options = pattern.code == "sentence-start-lowercase" ? [] : [.caseInsensitive]
        if let match = firstMatch(pattern: pattern.pattern, in: text, options: options) {
            issues.append(ReportLanguageIssue(code: pattern.code, severity: .error, message: pattern.message, excerpt: match, source: .customRule))
        }
    }

    if let wrongPronoun = wrongPronounIssue(text: text, expectedSubjectPronoun: expectedSubjectPronoun) {
        issues.append(wrongPronoun)
    }

    repeatedWordIssues(text).forEach { issues.append($0) }
    articleIssues(text).forEach { issues.append($0) }
    if allowWarnings {
        longSentenceWarnings(text).forEach { issues.append($0) }
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
    SevereLanguagePattern(code: "shown-name", pattern: #"has also shown\s+[A-Z][a-z]+\b"#, message: "A report note appears to have been wrapped around a full sentence."),
    SevereLanguagePattern(code: "shown-needs", pattern: #"has also shown\s+needs\b"#, message: "A growth note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "shown-has", pattern: #"has also shown\s+has\b"#, message: "A growth note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "shown-pronoun", pattern: #"has also shown\s+(she|he|they)\b"#, message: "A report note was inserted into the wrong sentence frame."),
    SevereLanguagePattern(code: "demonstrated-pronoun", pattern: #"demonstrated this during\s+(She|He|They)\b"#, message: "Evidence was inserted into a sentence frame incorrectly."),
    SevereLanguagePattern(code: "shown-gerund", pattern: #"has(?: also)? shown\s+(using|applying|checking|explaining|organising|organizing|writing|reading|sharing|analysing|analyzing|comparing|creating|solving|listening|participating|describing|identifying|developing|reflecting|editing|reviewing|completing)\b"#, message: "A report note was inserted into a sentence frame that needs a noun phrase or complete sentence."),
    SevereLanguagePattern(code: "benefit-from-bare-verb", pattern: #"\bwould benefit from\s+(apply|attempt|check|compare|complete|create|describe|develop|edit|explain|identify|listen|organise|organize|participate|read|reflect|review|share|solve|thank|use|write|analyse|analyze)\b"#, message: "A growth note uses a bare verb after \"would benefit from\"."),
    SevereLanguagePattern(code: "adjective-adverb-analyse", pattern: #"\bThey\s+(insightful|detailed)\s+analyse\b"#, message: "A corpus phrase uses an adjective where an adverbial phrase is needed before \"analyse\"."),
    SevereLanguagePattern(code: "adjective-adverb-compare", pattern: #"\bThey\s+(insightful|detailed)\s+compare\b"#, message: "A corpus phrase uses an adjective where an adverbial phrase is needed before \"compare\"."),
    SevereLanguagePattern(code: "designed-investigations-modifier", pattern: #"\bthrough\s+(insightful|detailed)\s+designed investigations\b"#, message: "A modifier before \"designed investigations\" is grammatically unsafe."),
    SevereLanguagePattern(code: "subject-verb-agreement", pattern: #"\b(?:He|She)\s+(apply|attempt|check|compare|complete|create|describe|develop|edit|explain|identify|listen|organise|organize|participate|read|reflect|review|share|solve|thank|use|write|analyse|analyze)\b|\bThey\s+(applies|attempts|checks|compares|completes|creates|describes|develops|edits|explains|identifies|listens|organises|organizes|participates|reads|reflects|reviews|shares|solves|thanks|uses|writes|analyses|analyzes)\b|\b(?:He|She)\s+\w+s\b[^.!?;:]*\band\s+(apply|attempt|check|compare|complete|create|describe|develop|edit|explain|identify|listen|organise|organize|participate|read|reflect|review|share|solve|thank|use|write|analyse|analyze)\b"#, message: "A pronoun and verb do not agree."),
    SevereLanguagePattern(code: "double-space", pattern: #" {2,}|\t+"#, message: "The report contains repeated spacing."),
    SevereLanguagePattern(code: "space-before-punctuation", pattern: #"\s+([,.;:!?])"#, message: "The report contains a space before punctuation."),
    SevereLanguagePattern(code: "repeated-terminal-punctuation", pattern: #"[!?]{2,}|,{2,}|(?<!\b[A-Z])\.{2,}"#, message: "The report contains repeated punctuation."),
    SevereLanguagePattern(code: "sentence-start-lowercase", pattern: #"(^|[.!?]\s+)[a-z](?=[a-z])"#, message: "A sentence appears to start with a lowercase letter.")
]

private let articlePatterns: [SevereLanguagePattern] = [
    SevereLanguagePattern(code: "article-agreement", pattern: #"\ba\s+(achievement|activity|accurate|area|assessment|effective|engaging|excellent|example|idea|improvement|insight|insightful|investigation|opportunity|outcome|understanding)\b"#, message: "The article \"a\" appears before a word that usually needs \"an\"."),
    SevereLanguagePattern(code: "article-agreement", pattern: #"\ban\s+(one|unit|unique|university|useful|year|young)\b"#, message: "The article \"an\" appears before a word that usually needs \"a\".")
]

private func wrongPronounIssue(text: String, expectedSubjectPronoun: String) -> ReportLanguageIssue? {
    let expected = expectedSubjectPronoun.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard ["he", "she", "they"].contains(expected) else { return nil }
    guard let match = firstMatch(pattern: #"(?:^|[.!?]\s+)(He|She|They)\b"#, in: text),
          let pronoun = firstMatch(pattern: #"\b(He|She|They)\b"#, in: match)
    else { return nil }
    guard pronoun.lowercased() != expected else { return nil }
    return ReportLanguageIssue(
        code: "wrong-pronoun",
        severity: .error,
        message: "The report uses \"\(pronoun)\" where the student's subject pronoun is \"\(expectedSubjectPronoun)\".",
        excerpt: match,
        suggestion: "Use \"\(expectedSubjectPronoun)\" for this student.",
        source: .customRule
    )
}

private func repeatedWordIssues(_ text: String) -> [ReportLanguageIssue] {
    guard let regex = try? NSRegularExpression(pattern: #"\b([A-Za-z][A-Za-z'’-]*)\s+\1\b"#, options: [.caseInsensitive]) else { return [] }
    var seen = Set<String>()
    return regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)).compactMap { match in
        guard let range = Range(match.range, in: text) else { return nil }
        let excerpt = String(text[range])
        let normalized = excerpt.lowercased()
        guard seen.insert(normalized).inserted else { return nil }
        return ReportLanguageIssue(code: "repeated-word", severity: .error, message: "The same word appears twice in a row.", excerpt: excerpt, suggestion: "Remove the repeated word.", source: .customRule)
    }
}

private func articleIssues(_ text: String) -> [ReportLanguageIssue] {
    articlePatterns.compactMap { pattern in
        firstMatch(pattern: pattern.pattern, in: text, options: [.caseInsensitive]).map {
            ReportLanguageIssue(code: pattern.code, severity: .error, message: pattern.message, excerpt: $0, source: .customRule)
        }
    }
}

private func longSentenceWarnings(_ text: String) -> [ReportLanguageIssue] {
    sentences(in: text)
        .filter { sentence in words(in: sentence).count > 45 }
        .prefix(1)
        .map { sentence in
            ReportLanguageIssue(
                code: "long-sentence",
                severity: .warning,
                message: "This sentence is long enough that it may be hard for families to read.",
                excerpt: String(sentence.prefix(160)),
                suggestion: "Consider splitting it into two shorter sentences.",
                source: .customRule
            )
        }
}

private func sentences(in text: String) -> [String] {
    text
        .components(separatedBy: CharacterSet(charactersIn: ".!?"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func words(in text: String) -> [String] {
    text
        .components(separatedBy: .whitespacesAndNewlines)
        .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        .filter { !$0.isEmpty }
}

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
