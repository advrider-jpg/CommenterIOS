import Foundation

private let maxReportContextFieldLength = 120
private let leadingPronounPattern = #"^(he|she|they|i|we)\b"#
private let subordinateClausePattern = #"^(because|when|while|although|if|as)\b"#
private let finiteVerbPattern = #"\b(am|are|is|was|were|be|being|been|has|have|had|do|does|did|can|could|will|would|shall|should|may|might|must|wrote|writes|write|created|creates|create|solved|solves|solve|used|uses|use|made|makes|make|completed|completes|complete|demonstrated|demonstrates|demonstrate|explained|explains|explain|identified|identifies|identify|analysed|analyses|analyse|analyzed|analyzes|analyze|applied|applies|apply|checked|checks|check|showed|shows|show|read|reads|worked|works|work|participated|participates|participate|contributed|contributes|contribute|planned|plans|plan|kept|keeps|keep|listened|listens|listen|focused|focuses|focus|improved|improves|improve|attempted|attempts|attempt|organised|organises|organise|organized|organizes|organize)\b"#
private let leadingFinitePattern = #"^(am|are|is|was|were|has|have|had|do|does|did|can|could|will|would|should|wrote|writes|write|created|creates|create|solved|solves|solve|used|uses|use|made|makes|make|completed|completes|complete|demonstrated|demonstrates|demonstrate|explained|explains|explain|identified|identifies|identify|analysed|analyses|analyse|analyzed|analyzes|analyze|applied|applies|apply|checked|checks|check|showed|shows|show|worked|works|work|participated|participates|participate|contributed|contributes|contribute|planned|plans|plan|kept|keeps|keep|listened|listens|listen|focused|focuses|focus|improved|improves|improve|attempted|attempts|attempt|organised|organises|organise|organized|organizes|organize)\b"#

public struct StoredProjectValidation: Equatable, Sendable {
    public var ok: Bool
    public var issues: [String]

    public init(ok: Bool, issues: [String]) {
        self.ok = ok
        self.issues = issues
    }
}

public func validateStoredProjectShape(_ project: Project) -> StoredProjectValidation {
    var issues: [String] = []

    if project.metadata.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Project id is required.")
    }
    if project.metadata.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Project name is required.")
    }
    if project.metadata.term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("Project term is required.")
    }

    project.metadata.selectedSubjects.forEach { key, subject in
        if key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            subject.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Selected subjects must include valid subject entries.")
        }
    }

    let rosterIds = Set(project.roster.map(\.id))
    if rosterIds.count != project.roster.count {
        issues.append("Student ids must be unique.")
    }
    if hasUnresolvedDuplicateStudents(roster: project.roster) {
        issues.append("Duplicate student identities must be resolved.")
    }

    let selectedSubjects = Set(project.metadata.selectedSubjects.keys)
    var seenResultKeys = Set<String>()
    project.results.forEach { result in
        let key = "\(result.studentId)::\(result.subject)"
        if !rosterIds.contains(result.studentId) {
            issues.append("Result references an unknown student.")
        }
        if !selectedSubjects.contains(result.subject) {
            issues.append("Result references an unselected subject.")
        }
        if seenResultKeys.contains(key) {
            issues.append("Result rows must be unique per student and subject.")
        }
        seenResultKeys.insert(key)
        if let issue = validateReportContextField(result.textType, label: "Text type / genre") {
            issues.append(issue)
        }
        if let issue = validateReportContextField(result.learningContext, label: "Learning context / activity") {
            issues.append(issue)
        }
    }
    var seenReportKeys = Set<String>()
    project.reports.forEach { report in
        let key = "\(report.studentId)::\(report.subject)"
        if !rosterIds.contains(report.studentId) {
            issues.append("Report references an unknown student.")
        }
        if !selectedSubjects.contains(report.subject) {
            issues.append("Report references an unselected subject.")
        }
        if seenReportKeys.contains(key) {
            issues.append("Reports must be unique per student and subject.")
        }
        seenReportKeys.insert(key)
    }

    issues.append(contentsOf: validateProjectSizeLimits(project).map(\.message))

    return StoredProjectValidation(ok: issues.isEmpty, issues: issues)
}

private func validateReportContextField(_ value: String?, label: String) -> String? {
    guard let value else { return nil }
    let normalized = normalizeReportContextField(value)
    guard !normalized.isEmpty else { return nil }

    if value.contains("\r") || value.contains("\n") {
        return "\(label) must be a short phrase, not multiple lines."
    }
    if containsTemplateToken(value) {
        return "\(label) must not contain template placeholders such as [context] or {Name}."
    }
    if normalized.count > maxReportContextFieldLength {
        return "\(label) must be \(maxReportContextFieldLength) characters or fewer."
    }
    if matches(leadingPronounPattern, normalized) {
        return "\(label) must be a short phrase without leading pronouns."
    }
    if matches(subordinateClausePattern, normalized) {
        return "\(label) must be a short phrase, not a subordinate clause."
    }
    if looksLikeSentenceStart(normalized) {
        return "\(label) must be a short phrase, not a sentence."
    }
    return nil
}

private func normalizeReportContextField(_ value: String) -> String {
    let collapsed = value
        .components(separatedBy: CharacterSet(charactersIn: "\t\r\n "))
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".!?;:"))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let lowercased = trimmed.lowercased()
    if trimmed.isEmpty || ["n/a", "na", "not applicable", "none", "null", "-", "\u{2014}"].contains(lowercased) {
        return ""
    }
    return trimmed
}

private func containsTemplateToken(_ value: String) -> Bool {
    value.range(of: #"\[[^\]]+\]|\{[^}]+\}"#, options: .regularExpression) != nil
}

private func looksLikeSentenceStart(_ value: String) -> Bool {
    if matches(leadingFinitePattern, value) { return true }
    if value.range(of: #"^[A-Z][A-Za-z'’-]+\s+"#, options: .regularExpression) != nil, matches(finiteVerbPattern, value) {
        return true
    }
    return false
}

private func matches(_ pattern: String, _ value: String) -> Bool {
    value.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}
