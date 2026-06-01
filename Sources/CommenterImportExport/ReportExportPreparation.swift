import CommentEngine
import CommenterDomain
import Foundation

public enum ReportExportPreparationError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)
    case notReady([String])

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) is not a report export format."
        case let .notReady(issues):
            guard let first = issues.first else {
                return "Reports are not ready for export."
            }
            let remaining = issues.count - 1
            if remaining > 0 {
                return "\(first) \(remaining) more issue\(remaining == 1 ? "" : "s") must be fixed."
            }
            return first
        }
    }
}

public struct ReportReviewRow: Equatable, Sendable {
    public static let headers = [
        "Student Name",
        "Year Level",
        "Subject",
        "Specific Subject",
        "Achievement Level",
        "Report Text",
        "Manual Edit Used",
        "Generated Date",
        "Project Name",
        "Term"
    ]

    public var studentName: String
    public var yearLevel: String
    public var subject: String
    public var specificSubject: String
    public var achievementLevel: String
    public var reportText: String
    public var manualEditUsed: String
    public var generatedDate: String
    public var projectName: String
    public var term: String

    public init(
        studentName: String,
        yearLevel: String,
        subject: String,
        specificSubject: String,
        achievementLevel: String,
        reportText: String,
        manualEditUsed: String,
        generatedDate: String,
        projectName: String,
        term: String
    ) {
        self.studentName = studentName
        self.yearLevel = yearLevel
        self.subject = subject
        self.specificSubject = specificSubject
        self.achievementLevel = achievementLevel
        self.reportText = reportText
        self.manualEditUsed = manualEditUsed
        self.generatedDate = generatedDate
        self.projectName = projectName
        self.term = term
    }

    public var orderedValues: [String] {
        [
            studentName,
            yearLevel,
            subject,
            specificSubject,
            achievementLevel,
            reportText,
            manualEditUsed,
            generatedDate,
            projectName,
            term
        ]
    }
}

public struct PreparedReportPacket: Equatable, Sendable {
    public var title: String
    public var subtitle: String
    public var summary: String?
    public var students: [PreparedStudentReports]

    public init(title: String, subtitle: String, summary: String?, students: [PreparedStudentReports]) {
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.students = students
    }
}

public struct PreparedStudentReports: Equatable, Sendable {
    public var displayName: String
    public var detail: String
    public var sections: [PreparedSubjectReport]

    public init(displayName: String, detail: String, sections: [PreparedSubjectReport]) {
        self.displayName = displayName
        self.detail = detail
        self.sections = sections
    }
}

public struct PreparedSubjectReport: Equatable, Sendable {
    public var subject: String
    public var achievement: String
    public var focus: String?
    public var paragraphs: [String]

    public init(subject: String, achievement: String, focus: String?, paragraphs: [String]) {
        self.subject = subject
        self.achievement = achievement
        self.focus = focus
        self.paragraphs = paragraphs
    }
}

public func reportParagraphs(_ text: String) -> [String] {
    var paragraphs: [String] = []
    var current: [String] = []
    text.components(separatedBy: .newlines).forEach { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if !current.isEmpty {
                paragraphs.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
                current.removeAll()
            }
        } else {
            current.append(line)
        }
    }
    if !current.isEmpty {
        paragraphs.append(current.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return paragraphs.filter { !$0.isEmpty }
}

public func spreadsheetSafeText(_ value: String?) -> String {
    let text = value ?? ""
    let firstNonWhitespace = text.first { !$0.isWhitespace }
    if let firstNonWhitespace, ["=", "+", "-", "@"].contains(String(firstNonWhitespace)) {
        return "'\(text)"
    }
    return text
}

public func reportReviewRows(project: Project, studentId: String? = nil) throws -> [ReportReviewRow] {
    let scope = try validatedReportExportScope(project: project, studentId: studentId)
    return try scope.students.flatMap { student in
        try scope.subjects.map { subject in
            guard let report = project.reports.first(where: { $0.studentId == student.id && $0.subject == subject }) else {
                throw ReportExportPreparationError.notReady(["\(displayStudentName(project: project, student: student)) does not have a generated report for \(displaySubjectName(subject))."])
            }
            guard let result = project.results.first(where: { $0.studentId == student.id && $0.subject == subject }) else {
                throw ReportExportPreparationError.notReady(["\(displayStudentName(project: project, student: student)) is missing an achievement result for \(displaySubjectName(subject))."])
            }
            return ReportReviewRow(
                studentName: spreadsheetSafeText(fullStudentName(student)),
                yearLevel: spreadsheetSafeText(student.yearLevel.rawValue),
                subject: spreadsheetSafeText(displaySubjectName(subject)),
                specificSubject: spreadsheetSafeText(result.focusStrand ?? ""),
                achievementLevel: spreadsheetSafeText(result.achievementLevel?.rawValue ?? ""),
                reportText: spreadsheetSafeText(try exportReportText(report)),
                manualEditUsed: report.manualEdit?.isEmpty == false ? "Yes" : "No",
                generatedDate: generatedDateString(report.generatedAt),
                projectName: spreadsheetSafeText(project.metadata.name),
                term: spreadsheetSafeText(project.metadata.term)
            )
        }
    }
}

public func prepareReportPacket(project: Project, studentId: String? = nil) throws -> PreparedReportPacket {
    let scope = try validatedReportExportScope(project: project, studentId: studentId)
    let students = try scope.students.map { student in
        let sections = try scope.subjects.map { subject in
            guard let report = project.reports.first(where: { $0.studentId == student.id && $0.subject == subject }),
                  let result = project.results.first(where: { $0.studentId == student.id && $0.subject == subject }),
                  let achievement = result.achievementLevel
            else {
                throw ReportExportPreparationError.notReady(["\(displayStudentName(project: project, student: student)) is missing export-ready data for \(displaySubjectName(subject))."])
            }
            let focus = result.focusStrand?.trimmingCharacters(in: .whitespacesAndNewlines)
            return PreparedSubjectReport(
                subject: displaySubjectName(subject),
                achievement: achievement.rawValue,
                focus: focus?.isEmpty == false && focus != subject ? focus : nil,
                paragraphs: reportParagraphs(try exportReportText(report))
            )
        }
        return PreparedStudentReports(
            displayName: displayStudentName(project: project, student: student),
            detail: "\(student.yearLevel.rawValue) \(bullet) \(project.metadata.term)",
            sections: sections
        )
    }

    return PreparedReportPacket(
        title: project.metadata.name,
        subtitle: "\(projectYearLabel(project)) \(bullet) \(project.metadata.term)",
        summary: studentId == nil ? "\(plural(scope.students.count, "student")) \(bullet) \(plural(scope.subjects.count, "subject"))" : nil,
        students: students
    )
}

public func reportExportFilename(project: Project, format: ImportExportFormat, studentId: String? = nil) throws -> String {
    guard [.docx, .xlsx, .xls].contains(format) else {
        throw ReportExportPreparationError.unsupportedFormat(format)
    }
    let base = safeFileName(project.metadata.name, fallback: "Commenter")
    let suffix: String
    if let studentId {
        guard let student = project.roster.first(where: { $0.id == studentId }) else {
            throw ReportExportPreparationError.notReady(["The selected student was not found in this project."])
        }
        suffix = "_\(safeFileName(student.firstName, fallback: "Student"))"
    } else {
        suffix = ""
    }
    switch format {
    case .docx:
        return "\(base)\(suffix)_Reports.docx"
    case .xlsx, .xls:
        return "\(base)\(suffix)_Report_Review.\(format.rawValue)"
    case .csv, .backupJSON:
        throw ReportExportPreparationError.unsupportedFormat(format)
    }
}

private struct ValidatedReportExportScope {
    var students: [Student]
    var subjects: [String]
}

private let bullet = "\u{2022}"

private func validatedReportExportScope(project: Project, studentId: String?) throws -> ValidatedReportExportScope {
    let storedShape = validateStoredProjectShape(project)
    if !storedShape.ok {
        throw ReportExportPreparationError.notReady(storedShape.issues)
    }

    let students: [Student]
    if let studentId {
        students = project.roster.filter { $0.id == studentId }
        if students.isEmpty {
            throw ReportExportPreparationError.notReady(["The selected student was not found in this project."])
        }
    } else {
        students = project.roster
    }

    let subjects = selectedSubjectKeys(project.metadata.selectedSubjects)
    var issues: [String] = []
    if students.isEmpty {
        issues.append("There are no students to export.")
    }
    if subjects.isEmpty {
        issues.append("There are no selected subjects to export.")
    }
    students.forEach { student in
        subjects.forEach { subject in
            let readiness = getReportReadiness(project: project, studentId: student.id, subject: subject)
            if !isReadyForExport(readiness.status) {
                issues.append(readiness.message)
            }
        }
    }
    if !issues.isEmpty {
        throw ReportExportPreparationError.notReady(issues)
    }
    return ValidatedReportExportScope(students: students, subjects: subjects)
}

private func exportReportText(_ report: GeneratedReport) throws -> String {
    let text = report.manualEdit?.isEmpty == false ? report.manualEdit ?? "" : report.text
    let placeholders = findUnresolvedPlaceholders(text)
    if !placeholders.isEmpty {
        throw ReportExportPreparationError.notReady(["\(displaySubjectName(report.subject)) report contains template text that must be replaced."])
    }
    return text
}

private func displayStudentName(project: Project, student: Student) -> String {
    let first = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let full = fullStudentName(student)
    let display = project.metadata.useFirstNameOnly ? (first.isEmpty ? full : first) : full
    return display.isEmpty ? "Student" : display
}

private func fullStudentName(_ student: Student) -> String {
    let first = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let last = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    return full.isEmpty ? "Student" : full
}

private func projectYearLabel(_ project: Project) -> String {
    switch project.metadata.yearLevel {
    case .year5:
        return "Year 5"
    case .year6:
        return "Year 6"
    case .mixed:
        return "Mixed"
    }
}

private func plural(_ count: Int, _ singular: String) -> String {
    "\(count) \(count == 1 ? singular : "\(singular)s")"
}

private func generatedDateString(_ milliseconds: Int64) -> String {
    guard milliseconds > 0 else { return "" }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1000))
}

private func safeFileName(_ value: String, fallback: String) -> String {
    let allowedPunctuation = CharacterSet(charactersIn: " _-")
    let filtered = value.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.map { scalar -> Character in
        if CharacterSet.alphanumerics.contains(scalar) || allowedPunctuation.contains(scalar) {
            return Character(scalar)
        }
        return "_"
    }
    let collapsed = String(String(filtered)
        .replacingOccurrences(of: #"_+"#, with: "_", options: .regularExpression)
        .prefix(120))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if collapsed.range(of: #"[A-Za-z0-9]"#, options: .regularExpression) == nil {
        return fallback
    }
    return collapsed
}
