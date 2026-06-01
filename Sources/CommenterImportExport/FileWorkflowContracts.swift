import Foundation

public enum ImportExportFormat: String, Codable, Equatable, Hashable, Sendable {
    case csv
    case xlsx
    case xls
    case docx
    case backupJSON
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
