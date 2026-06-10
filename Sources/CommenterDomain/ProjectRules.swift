import Foundation

public enum ProjectLimits {
    public static let backupBytes = 128 * 1024 * 1024
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

public func reconcileProjectForPersistence(_ project: Project, nowMilliseconds: Int64) -> Project {
    let rosterIds = Set(project.roster.map(\.id))
    let subjects = Set(project.metadata.selectedSubjects.keys)

    var metadata = project.metadata
    metadata.reportLayout = normalizeReportLayout(project.metadata.reportLayout)
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

    appendIssue(&issues, when: project.metadata.name.count > ProjectLimits.projectNameCharacters, code: "project-name-too-long", message: "Project name must be \(ProjectLimits.projectNameCharacters) characters or fewer.")
    appendIssue(&issues, when: project.metadata.term.count > ProjectLimits.termCharacters, code: "project-term-too-long", message: "Project term must be \(ProjectLimits.termCharacters) characters or fewer.")
    appendIssue(&issues, when: project.roster.count > ProjectLimits.students, code: "too-many-students", message: "A project can contain up to \(ProjectLimits.students) students.")
    appendIssue(&issues, when: project.metadata.selectedSubjects.count > ProjectLimits.subjects, code: "too-many-subjects", message: "A project can contain up to \(ProjectLimits.subjects) selected subjects.")
    appendIssue(&issues, when: project.results.count > ProjectLimits.results, code: "too-many-results", message: "A project can contain up to \(ProjectLimits.results) achievement results.")
    appendIssue(&issues, when: project.reports.count > ProjectLimits.reports, code: "too-many-reports", message: "A project can contain up to \(ProjectLimits.reports) generated reports.")

    project.roster.forEach { student in
        appendIssue(&issues, when: student.firstName.count > ProjectLimits.studentNameCharacters || student.lastName.count > ProjectLimits.studentNameCharacters, code: "student-name-too-long", message: "Student names are too long for this project.")
        [student.internalTeacherNote, student.reportEmphasisNote, student.comments].forEach {
            appendIssue(&issues, when: ($0?.count ?? 0) > ProjectLimits.studentNoteCharacters, code: "student-note-too-long", message: "Student notes are too long for this project.")
        }
    }

    project.results.forEach { result in
        [result.evidenceText, result.reportEmphasisNote, result.commentsText, result.internalTeacherNote].forEach {
            appendIssue(&issues, when: ($0?.count ?? 0) > ProjectLimits.resultFreeTextCharacters, code: "result-text-too-long", message: "Result notes are too long for this project.")
        }
        [result.englishFocusTags, result.mathProficiencies, result.mathMindsetToggles, result.nextStepGoals].forEach {
            appendIssue(&issues, when: ($0?.count ?? 0) > ProjectLimits.resultArrayItems, code: "result-array-too-long", message: "A result has too many selected focus values.")
        }
    }

    project.reports.forEach { report in
        appendIssue(&issues, when: report.text.count > ProjectLimits.reportTextCharacters || (report.manualEdit?.count ?? 0) > ProjectLimits.manualEditCharacters, code: "report-text-too-long", message: "A generated report is too long for this project.")
        appendIssue(&issues, when: report.variantIds.count > ProjectLimits.variantIdsPerReport, code: "report-variant-list-too-long", message: "A generated report has too much internal variant history.")
    }

    return issues
}

private func appendIssue(_ issues: inout [ProjectLimitIssue], when condition: Bool, code: String, message: String) {
    if condition {
        issues.append(ProjectLimitIssue(code: code, message: message))
    }
}
