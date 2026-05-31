import CommenterDomain
import Foundation

public enum ImportExportFormat: String, Codable, Equatable, Sendable {
    case csv
    case xlsx
    case xls
    case docx
    case backupJSON
}

public enum FileWorkflowState: Equatable, Sendable {
    case unavailable(String)
    case prepared(URL)
    case saved(URL)
    case shared(URL)
    case cancelled
    case failed(String)
}

public enum ImportExportError: LocalizedError, Equatable {
    case unavailable(format: ImportExportFormat, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(format, reason):
            return "\(format.rawValue.uppercased()) support is unavailable: \(reason)"
        }
    }
}

public struct ImportPreview: Equatable, Sendable {
    public var sourceFormat: ImportExportFormat
    public var acceptedRows: Int
    public var errors: [String]

    public init(sourceFormat: ImportExportFormat, acceptedRows: Int, errors: [String]) {
        self.sourceFormat = sourceFormat
        self.acceptedRows = acceptedRows
        self.errors = errors
    }
}

public protocol SpreadsheetImporting: Sendable {
    func previewRosterImport(from url: URL, format: ImportExportFormat) async throws -> ImportPreview
    func previewResultsImport(from url: URL, format: ImportExportFormat) async throws -> ImportPreview
}

public protocol ReportExporting: Sendable {
    func exportReports(project: Project, format: ImportExportFormat) async throws -> URL
}

public struct UnavailableImportExporter: SpreadsheetImporting, ReportExporting {
    public let reason: String

    public init(reason: String = "The production import/export implementation has not been ported yet.") {
        self.reason = reason
    }

    public func previewRosterImport(from url: URL, format: ImportExportFormat) async throws -> ImportPreview {
        throw ImportExportError.unavailable(format: format, reason: reason)
    }

    public func previewResultsImport(from url: URL, format: ImportExportFormat) async throws -> ImportPreview {
        throw ImportExportError.unavailable(format: format, reason: reason)
    }

    public func exportReports(project: Project, format: ImportExportFormat) async throws -> URL {
        throw ImportExportError.unavailable(format: format, reason: reason)
    }
}
