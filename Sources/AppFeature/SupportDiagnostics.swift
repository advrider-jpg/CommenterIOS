import CommentEngine
import CommenterDomain
import CommenterImportExport
import Foundation

public struct AppBuildInfo: Equatable, Sendable {
    public var displayName: String
    public var version: String
    public var build: String

    public init(displayName: String, version: String, build: String) {
        self.displayName = displayName
        self.version = version
        self.build = build
    }

    public static func current(bundle: Bundle = .main) -> AppBuildInfo {
        AppBuildInfo(
            displayName: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "Report Writer",
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        )
    }
}

public enum CommenterFormatters {
    public static func integer(_ value: Int, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    public static func timestamp(
        _ milliseconds: Int64?,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        guard let milliseconds, milliseconds > 0 else {
            return "Not yet recorded"
        }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date(timeIntervalSince1970: Double(milliseconds) / 1000))
    }
}

public func supportDiagnosticsText(
    state: AppFeature.State,
    buildInfo: AppBuildInfo = .current(),
    locale: Locale = .current,
    timeZone: TimeZone = .current
) -> String {
    var lines: [String] = []
    lines.append("Report Writer Support Diagnostics")
    lines.append("App: \(buildInfo.displayName)")
    lines.append("App version: \(buildInfo.version)")
    lines.append("Build: \(buildInfo.build)")
    lines.append("")

    switch state.datasetStatus {
    case .notLoaded:
        lines.append("Dataset: not loaded")
    case .loading:
        lines.append("Dataset: loading")
    case let .failed(message):
        lines.append("Dataset: failed - \(message)")
    case let .loaded(snapshot):
        lines.append("Dataset: bundled production dataset loaded")
        lines.append("Dataset validated: \(CommenterFormatters.timestamp(snapshot.loadedAtMilliseconds, locale: locale, timeZone: timeZone))")
        lines.append("Bundled hash: \(snapshot.hash)")
        lines.append("Normalized source hash: \(snapshot.normalizedSourceHash)")
        lines.append("Hash verification: \(snapshot.hash == snapshot.normalizedSourceHash ? "verified match" : "mismatch requires investigation")")
        lines.append("Structural checks: schema, subjects, components, recipes, variants, and uniqueness guards")
        lines.append("Subjects: \(CommenterFormatters.integer(snapshot.subjectCount, locale: locale))")
        lines.append("Components: \(CommenterFormatters.integer(snapshot.componentCount, locale: locale))")
        lines.append("Recipes: \(CommenterFormatters.integer(snapshot.recipeCount, locale: locale))")
        lines.append("Assembled variants: \(CommenterFormatters.integer(snapshot.assembledVariantCount, locale: locale))")
        lines.append("Uniqueness guards: \(CommenterFormatters.integer(snapshot.uniquenessGuardCount, locale: locale))")
        if !snapshot.warnings.isEmpty {
            lines.append("Dataset warnings: \(snapshot.warnings.joined(separator: " | "))")
        }
    }

    lines.append("")
    lines.append("Project storage status: \(projectStorageStatusDescription(state.projectStorageStatus))")
    lines.append("Project storage message: \(state.projectStorageMessage)")
    lines.append("Projects on device: \(CommenterFormatters.integer(state.projects.count, locale: locale))")
    if !state.invalidProjectRecords.isEmpty {
        lines.append("Invalid local project records:")
        state.invalidProjectRecords.forEach { record in
            lines.append("- \(record.id): \(record.reason)")
        }
    }

    if let project = state.selectedProject {
        lines.append("")
        lines.append("Open project: \(project.metadata.name)")
        lines.append("Project id: \(project.metadata.id)")
        lines.append("Term: \(project.metadata.term)")
        lines.append("Year level: \(projectYearLabel(project.metadata.yearLevel))")
        lines.append("Last saved: \(CommenterFormatters.timestamp(project.metadata.persistence?.savedAt, locale: locale, timeZone: timeZone))")
        lines.append("Revision: \(project.metadata.persistence?.revision.map { String($0) } ?? "Not yet recorded")")
        lines.append("Fingerprint: \(project.metadata.persistence?.fingerprint ?? "Not yet recorded")")
        lines.append("Roster count: \(CommenterFormatters.integer(project.roster.count, locale: locale))")
        lines.append("Selected subjects: \(CommenterFormatters.integer(project.metadata.selectedSubjects.count, locale: locale))")
        lines.append("Results count: \(CommenterFormatters.integer(project.results.count, locale: locale))")
        lines.append("Draft reports count: \(CommenterFormatters.integer(project.reports.count, locale: locale))")
        if let readiness = state.selectedProjectReadiness {
            lines.append("Export readiness: \(readiness.ready) of \(readiness.expected)")
            if !readiness.blocked.isEmpty {
                lines.append("Blocked readiness: \(readiness.blocked.map(\.message).joined(separator: " | "))")
            }
        }
    } else {
        lines.append("")
        lines.append("Open project: none")
    }

    if !state.lastPreparedFiles.isEmpty {
        lines.append("")
        lines.append("Prepared files:")
        ImportExportFormat.preparationDisplayOrder.forEach { format in
            if let record = state.lastPreparedFiles[format] {
                lines.append("- \(format.supportLabel): \(record.filename), prepared \(CommenterFormatters.timestamp(record.preparedAtMilliseconds, locale: locale, timeZone: timeZone))")
            }
        }
    }

    lines.append("")
    lines.append("Privacy: project, roster, results, drafts, backups, and exports stay local unless the user chooses a native export or share destination.")
    lines.append("Backup guidance: prepare Backup JSON before destructive edits, device migration, or support troubleshooting.")
    return lines.joined(separator: "\n")
}

public func projectStorageStatusDescription(_ status: AppFeature.ProjectStorageStatus) -> String {
    switch status {
    case .notLoaded:
        return "Not loaded"
    case .loading:
        return "Loading"
    case .loaded:
        return "Loaded"
    case .creating:
        return "Creating project"
    case .loadingProject:
        return "Loading project"
    case .saving:
        return "Saving"
    case .deleting:
        return "Deleting project"
    case .preparingFile:
        return "Preparing file"
    case .importing:
        return "Importing"
    case .generating:
        return "Generating reports"
    case let .failed(message):
        return "Failed - \(message)"
    }
}

public func projectYearLabel(_ yearLevel: ProjectYearLevel) -> String {
    switch yearLevel {
    case .year5:
        return "Year 5"
    case .year6:
        return "Year 6"
    case .mixed:
        return "Mixed"
    }
}

public extension ImportExportFormat {
    static let preparationDisplayOrder: [ImportExportFormat] = [.backupJSON, .docx, .xlsx, .xls]

    var supportLabel: String {
        switch self {
        case .backupJSON:
            return "Backup JSON"
        case .docx:
            return "DOCX reports"
        case .xlsx:
            return "XLSX review workbook"
        case .xls:
            return "XLS review workbook"
        case .csv:
            return "CSV"
        }
    }
}
