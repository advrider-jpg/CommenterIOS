import Foundation

public enum ProjectLimits {
    // The backup adds project-scoped metadata and readable JSON formatting to a
    // project that is itself capped at 12 MiB. This mirrors CommenterV3's
    // production contract rather than imposing an unrelated iOS-only limit.
    public static let backupBytes = 16 * 1024 * 1024
    public static let projectBytes = 12 * 1024 * 1024
    public static let projectNameCharacters = 120
    public static let termCharacters = 80
    public static let students = 300
    public static let subjects = 20
    public static let results = 6_000
    public static let reports = 6_000
    public static let reportTextCharacters = 8_000
    public static let manualEditCharacters = 8_000
    public static let variantIdsPerReport = 50
    public static let studentNameCharacters = 80
    public static let studentNoteCharacters = 1_000
    public static let resultFreeTextCharacters = 2_000
    public static let resultArrayItems = 8
    public static let resultArrayItemCharacters = 180
    public static let judgements = 1_000
    public static let strandsPerSubject = 80
    public static let substrandsPerStrand = 250
    public static let selectionNameCharacters = 180
    public static let flagsPerResult = 100
    public static let reportTraceBytes = 64 * 1024
    public static let jsonMaximumDepth = 20
    public static let jsonMaximumNodes = 100_000
    public static let jsonMaximumKeysPerObject = 1_000
    public static let unknownStringCharacters = 32_768
}

public struct ProjectLimitIssue: Equatable, Sendable {
    public var code: String
    public var message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public func defaultReportLayout() -> ReportLayout {
    ReportLayout()
}

public func normalizeReportLayout(_ layout: ReportLayout?) -> ReportLayout {
    let defaultLayout = defaultReportLayout()
    guard let layout else { return defaultLayout }

    var seenSections = Set<ReportSection>()
    let normalizedOrder = layout.order
        .filter { ReportSection.defaultOrder.contains($0) }
        .filter { seenSections.insert($0).inserted }
    let completedOrder = normalizedOrder + ReportSection.defaultOrder.filter { !seenSections.contains($0) }

    return ReportLayout(
        enabled: layout.enabled,
        order: completedOrder,
        include: [
            .general: layout.include[.general] != false,
            .subject: true,
            .dispositions: layout.include[.dispositions] != false,
            .nextSteps: layout.include[.nextSteps] != false
        ]
    )
}

public func selectedSubjectKeys(_ selectedSubjects: [String: SelectedSubject]) -> [String] {
    let curriculumOrder = teacherSubjectKeysInCurriculumOrder()
    let curriculumSet = Set(curriculumOrder)
    let orderedKnownSubjects = curriculumOrder.filter { selectedSubjects[$0] != nil }
    let customSubjects = selectedSubjects.keys.filter { !curriculumSet.contains($0) }.sorted()
    return orderedKnownSubjects + customSubjects
}

public func studentIdentityKey(_ student: Student) -> String {
    [
        student.firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        student.lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        student.yearLevel.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    ].joined(separator: "::")
}

public func duplicateStudentDisplayKeys(roster: [Student]) -> [String] {
    let grouped = Dictionary(grouping: roster, by: studentIdentityKey)
    return grouped
        .filter { !$0.key.hasPrefix("::") && $0.value.count > 1 }
        .map(\.key)
        .sorted()
}

public func hasUnresolvedDuplicateStudents(roster: [Student]) -> Bool {
    !duplicateStudentDisplayKeys(roster: roster).isEmpty
}

public func deriveProjectYearLevel(
    roster: [Student],
    fallback: ProjectYearLevel = .mixed
) -> ProjectYearLevel {
    let completedYears = Set(
        roster
            .filter {
                !$0.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !$0.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map(\.yearLevel)
    )
    if completedYears.isEmpty { return fallback }
    if completedYears.count > 1 { return .mixed }
    return completedYears.contains(.year6) ? .year6 : .year5
}

public func reconcileProjectForPersistence(_ project: Project, nowMilliseconds: Int64) -> Project {
    let rosterIds = Set(project.roster.map(\.id))
    let subjects = Set(project.metadata.selectedSubjects.keys)

    var metadata = project.metadata
    metadata.reportLayout = normalizeReportLayout(project.metadata.reportLayout)
    metadata.yearLevel = deriveProjectYearLevel(roster: project.roster, fallback: project.metadata.yearLevel)
    metadata.updatedAt = nowMilliseconds

    return Project(
        metadata: metadata,
        roster: project.roster,
        judgements: project.judgements,
        results: project.results.filter { rosterIds.contains($0.studentId) && subjects.contains($0.subject) },
        reports: project.reports.filter { rosterIds.contains($0.studentId) && subjects.contains($0.subject) }
    )
}

public func replaceReport(_ reports: [GeneratedReport], with report: GeneratedReport) -> [GeneratedReport] {
    var next = reports
    if let index = next.firstIndex(where: { $0.studentId == report.studentId && $0.subject == report.subject }) {
        next[index] = report
    } else {
        next.append(report)
    }
    return next
}

public func reportVariantIds(_ project: Project) -> [String] {
    project.reports.flatMap(\.variantIds).filter { !$0.isEmpty }
}

public func validateProjectSizeLimits(_ project: Project) -> [ProjectLimitIssue] {
    var issues: [ProjectLimitIssue] = []

    let hasSafeStructure = hasAcceptableJudgementComplexity(project.judgements)
    if !hasSafeStructure {
        appendIssue(&issues, when: true, code: "project-structure-too-complex", message: "Saved work contains legacy data that is too deeply nested or complex to store safely.")
    } else if let encoded = encodedProjectForValidation(project) {
        appendIssue(&issues, when: encoded.javaScriptByteCount > ProjectLimits.projectBytes, code: "project-too-large", message: "Saved work must be smaller than \(ProjectLimits.projectBytes / (1024 * 1024)) MB.")
        appendIssue(
            &issues,
            when: !hasAcceptableEncodedProjectComplexity(encoded.data),
            code: "project-structure-too-complex",
            message: "Saved work contains data that is too deeply nested or complex to store safely."
        )
    } else {
        appendIssue(&issues, when: true, code: "project-not-encodable", message: "Saved work contains a value that cannot be stored as JSON.")
    }
    appendIssue(&issues, when: project.metadata.name.utf16.count > ProjectLimits.projectNameCharacters, code: "project-name-too-long", message: "Project name must be \(ProjectLimits.projectNameCharacters) characters or fewer.")
    appendIssue(&issues, when: project.metadata.term.utf16.count > ProjectLimits.termCharacters, code: "project-term-too-long", message: "Project term must be \(ProjectLimits.termCharacters) characters or fewer.")
    appendIssue(&issues, when: project.roster.count > ProjectLimits.students, code: "too-many-students", message: "A project can contain up to \(ProjectLimits.students) students.")
    appendIssue(&issues, when: project.metadata.selectedSubjects.count > ProjectLimits.subjects, code: "too-many-subjects", message: "A project can contain up to \(ProjectLimits.subjects) selected subjects.")
    appendIssue(&issues, when: project.results.count > ProjectLimits.results, code: "too-many-results", message: "A project can contain up to \(ProjectLimits.results) achievement results.")
    appendIssue(&issues, when: project.reports.count > ProjectLimits.reports, code: "too-many-reports", message: "A project can contain up to \(ProjectLimits.reports) generated reports.")
    appendIssue(&issues, when: project.judgements.count > ProjectLimits.judgements, code: "judgements-too-large", message: "Legacy judgement data is too large for this saved work.")

    project.metadata.selectedSubjects.forEach { key, subject in
        appendIssue(
            &issues,
            when: key.utf16.count > ProjectLimits.selectionNameCharacters || subject.name.utf16.count > ProjectLimits.selectionNameCharacters,
            code: "subject-name-too-long",
            message: "A selected subject name is too long."
        )
        appendIssue(
            &issues,
            when: subject.strands.count > ProjectLimits.strandsPerSubject,
            code: "too-many-strands",
            message: "A selected subject contains too many curriculum strands."
        )
        subject.strands.forEach { strandKey, strand in
            appendIssue(
                &issues,
                when: strandKey.utf16.count > ProjectLimits.selectionNameCharacters || strand.name.utf16.count > ProjectLimits.selectionNameCharacters,
                code: "strand-name-too-long",
                message: "A selected curriculum strand name is too long."
            )
            appendIssue(
                &issues,
                when: strand.substrands.count > ProjectLimits.substrandsPerStrand,
                code: "too-many-substrands",
                message: "A selected curriculum strand contains too many substrands."
            )
            appendIssue(
                &issues,
                when: strand.substrands.contains { $0.utf16.count > ProjectLimits.selectionNameCharacters },
                code: "substrand-name-too-long",
                message: "A selected curriculum substrand name is too long."
            )
        }
    }

    project.roster.forEach { student in
        appendIssue(&issues, when: student.firstName.utf16.count > ProjectLimits.studentNameCharacters || student.lastName.utf16.count > ProjectLimits.studentNameCharacters, code: "student-name-too-long", message: "Student names are too long for this project.")
        [student.internalTeacherNote, student.reportEmphasisNote, student.comments].forEach {
            appendIssue(&issues, when: ($0?.utf16.count ?? 0) > ProjectLimits.studentNoteCharacters, code: "student-note-too-long", message: "Student notes are too long for this project.")
        }
    }

    project.results.forEach { result in
        [result.evidenceText, result.reportEmphasisNote, result.commentsText, result.internalTeacherNote].forEach {
            appendIssue(&issues, when: ($0?.utf16.count ?? 0) > ProjectLimits.resultFreeTextCharacters, code: "result-text-too-long", message: "Result notes are too long for this project.")
        }
        [result.englishFocusTags, result.mathProficiencies, result.mathMindsetToggles, result.nextStepGoals].forEach {
            appendIssue(&issues, when: ($0?.count ?? 0) > ProjectLimits.resultArrayItems, code: "result-array-too-long", message: "A result has too many selected focus values.")
            appendIssue(&issues, when: ($0 ?? []).contains { $0.utf16.count > ProjectLimits.resultArrayItemCharacters }, code: "result-array-item-too-long", message: "A selected result value is too long.")
        }
        appendIssue(&issues, when: (result.flags?.count ?? 0) > ProjectLimits.flagsPerResult, code: "too-many-result-flags", message: "A result contains too many internal flags.")
    }

    project.reports.forEach { report in
        appendIssue(&issues, when: report.text.utf16.count > ProjectLimits.reportTextCharacters || (report.manualEdit?.utf16.count ?? 0) > ProjectLimits.manualEditCharacters, code: "report-text-too-long", message: "A generated report is too long for this project.")
        appendIssue(&issues, when: report.variantIds.count > ProjectLimits.variantIdsPerReport, code: "report-variant-list-too-long", message: "A generated report has too much internal variant history.")
        appendIssue(
            &issues,
            when: (report.trace.map(jsonEncodedByteCount) ?? 0) > ProjectLimits.reportTraceBytes,
            code: "report-trace-too-large",
            message: "A generated report contains excessive internal diagnostics."
        )
    }

    return issues
}

private func appendIssue(_ issues: inout [ProjectLimitIssue], when condition: Bool, code: String, message: String) {
    if condition, !issues.contains(where: { $0.code == code }) {
        issues.append(ProjectLimitIssue(code: code, message: message))
    }
}

private func jsonEncodedByteCount(_ value: String) -> Int {
    javaScriptJSONString(.string(value)).utf8.count
}

private func encodedProjectForValidation(_ project: Project) -> (data: Data, javaScriptByteCount: Int)? {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(project)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        return (data, javaScriptJSONString(value).utf8.count)
    } catch {
        // The caller turns this into an explicit project-not-encodable issue.
        return nil
    }
}

private func hasAcceptableJudgementComplexity(_ judgements: [JSONValue]) -> Bool {
    // Project -> judgements array -> judgement value consumes two levels before
    // the legacy JSON value's own nesting begins.
    var stack = judgements.map { ($0, 2) }
    var nodes = 0
    while let (value, depth) = stack.popLast() {
        nodes += 1
        if nodes > ProjectLimits.jsonMaximumNodes || depth > ProjectLimits.jsonMaximumDepth {
            return false
        }
        switch value {
        case let .string(text):
            if text.utf16.count > ProjectLimits.unknownStringCharacters { return false }
        case let .array(values):
            stack.append(contentsOf: values.map { ($0, depth + 1) })
        case let .object(object):
            if object.count > ProjectLimits.jsonMaximumKeysPerObject || object.keys.contains(where: { $0.utf16.count > ProjectLimits.selectionNameCharacters }) {
                return false
            }
            stack.append(contentsOf: object.values.map { ($0, depth + 1) })
        case .number, .bool, .null:
            break
        }
    }
    return true
}

private func hasAcceptableEncodedProjectComplexity(_ data: Data) -> Bool {
    guard let root = try? JSONSerialization.jsonObject(with: data) else { return false }
    var stack: [(Any, Int)] = [(root, 0)]
    var nodes = 0
    while let (value, depth) = stack.popLast() {
        nodes += 1
        if nodes > ProjectLimits.jsonMaximumNodes || depth > ProjectLimits.jsonMaximumDepth {
            return false
        }
        if let text = value as? String, text.utf16.count > ProjectLimits.unknownStringCharacters {
            return false
        }
        if let values = value as? [Any] {
            stack.append(contentsOf: values.map { ($0, depth + 1) })
            continue
        }
        if let object = value as? [String: Any] {
            if object.count > ProjectLimits.jsonMaximumKeysPerObject ||
                object.keys.contains(where: { $0.utf16.count > ProjectLimits.selectionNameCharacters }) {
                return false
            }
            stack.append(contentsOf: object.values.map { ($0, depth + 1) })
        }
    }
    return true
}
