import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ImportMode {
    case backup
    case roster
    case results

    var allowedContentTypes: [UTType] {
        switch self {
        case .backup:
            return [.json, .commenterBackup]
        case .roster, .results:
            return [.commaSeparatedText, .xlsxWorkbook, .xlsWorkbook]
        }
    }
}

struct PreparedExportDocument: FileDocument {
    enum Error: LocalizedError {
        case missingPreparedFile(String)

        var errorDescription: String? {
            switch self {
            case let .missingPreparedFile(name):
                return "The prepared export file could not be read: \(name)"
            }
        }
    }

    static var readableContentTypes: [UTType] { [.data] }

    var url: URL
    var data: Data
    var contentType: UTType
    var defaultFilename: String

    init(url: URL) throws {
        self.url = url
        self.data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw Error.missingPreparedFile(url.lastPathComponent)
        }
        self.contentType = UTType(filenameExtension: url.pathExtension) ?? .data
        self.defaultFilename = url.deletingPathExtension().lastPathComponent
    }

    init(configuration: ReadConfiguration) throws {
        self.url = URL(fileURLWithPath: "")
        self.data = configuration.file.regularFileContents ?? Data()
        self.contentType = configuration.contentType
        self.defaultFilename = "CommenterExport"
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

extension UTType {
    static let xlsxWorkbook = UTType(filenameExtension: "xlsx") ?? .data
    static let xlsWorkbook = UTType(filenameExtension: "xls") ?? .data
    static let commenterBackup = UTType(filenameExtension: "commenter-backup.json") ?? .json
}

func isCancellation(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain, nsError.code == NSUserCancelledError {
        return true
    }
    return error is CancellationError || error.localizedDescription.localizedCaseInsensitiveContains("cancel")
}
