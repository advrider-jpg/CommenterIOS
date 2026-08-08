import Foundation

public enum CSVTemplateKind: Equatable, Sendable {
    case roster
    case achievementResults
}
public struct CSVTemplateDocument: Equatable, Sendable {
    public var filename: String
    public var mimeType: String
    public var text: String

    public init(filename: String, mimeType: String, text: String) {
        self.filename = filename
        self.mimeType = mimeType
        self.text = text
    }
}

public struct PreparedImportTemplateFile: Equatable, Sendable {
    public var url: URL
    public var byteCount: UInt64
    public var kind: CSVTemplateKind
    public var format: ImportExportFormat

    public init(url: URL, byteCount: UInt64, kind: CSVTemplateKind, format: ImportExportFormat) {
        self.url = url
        self.byteCount = byteCount
        self.kind = kind
        self.format = format
    }
}

public enum CSVTemplateError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) template export is unavailable here. CSV template serialization supports CSV only."
        }
    }
}

public enum ImportTemplateFileError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)
    case invalidDirectory(String)
    case emptyWrittenFile(URL)
    case verificationFailed(URL)
    case failedOutputCouldNotBeRemoved(URL)
    case generationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) is not a supported import-template format. Choose CSV, XLSX, or XLS."
        case let .invalidDirectory(path):
            return "The import-template destination is not a directory: \(path)"
        case let .emptyWrittenFile(url):
            return "The import template was written but is empty: \(url.lastPathComponent)"
        case let .verificationFailed(url):
            return "The import template was written but could not be verified: \(url.lastPathComponent)"
        case let .failedOutputCouldNotBeRemoved(url):
            return "Import-template preparation failed, and the incomplete or unverified output could not be removed: \(url.lastPathComponent). Do not use this file; remove it manually."
        case let .generationFailed(message):
            return "The import template could not be created: \(message)"
        }
    }
}

public enum CSVTemplates {
    public static let rosterFilenameStem = "report_writer_class_list_template"
    public static let achievementResultsFilenameStem = "report_writer_report_details_template"
    public static let rosterFilename = "\(rosterFilenameStem).csv"
    public static let achievementResultsFilename = "\(achievementResultsFilenameStem).csv"
    public static let csvMimeType = "text/csv;charset=utf-8"

    public static let rosterHeaders = [
        "First Name",
        "Last Name",
        "Year Level",
        "Gender",
        "Attitude",
        "General Comment Point",
        "Private Teacher Note"
    ]

    public static let achievementResultsHeaders = [
        "First Name",
        "Last Name",
        "Year Level",
        "Subject",
        "Achievement Level",
        "Focus",
        "Evidence",
        "Text Type",
        "Learning Context",
        "Point to Include in Comment",
        "English Focus Areas",
        "Mathematics Proficiency Areas",
        "Mathematics Learning Habits",
        "Next Step Goals"
    ]

    public static func rosterTemplateRows() -> [[String: String]] {
        [
            [
                "First Name": "John",
                "Last Name": "Doe",
                "Year Level": "Year 5",
                "Gender": "Male",
                "Attitude": "enthusiastic",
                "General Comment Point": "Uses feedback thoughtfully",
                "Private Teacher Note": "Private note; not included in reports"
            ],
            [
                "First Name": "Jane",
                "Last Name": "Smith",
                "Year Level": "Year 6",
                "Gender": "Female",
                "Attitude": "diligent",
                "General Comment Point": "",
                "Private Teacher Note": ""
            ]
        ]
    }

    public static func achievementResultsTemplateRows() -> [[String: String]] {
        [
            [
                "First Name": "John",
                "Last Name": "Doe",
                "Year Level": "Year 5",
                "Subject": "Mathematics",
                "Achievement Level": "At Standard",
                "Focus": "Number",
                "Evidence": "solved multi-step problems with working shown",
                "Text Type": "",
                "Learning Context": "",
                "Point to Include in Comment": "May appear in the draft comment",
                "English Focus Areas": "",
                "Mathematics Proficiency Areas": "Understanding, Fluency",
                "Mathematics Learning Habits": "Growth mindset, Checks working carefully",
                "Next Step Goals": "check working and show steps"
            ],
            [
                "First Name": "Jane",
                "Last Name": "Smith",
                "Year Level": "Year 6",
                "Subject": "English",
                "Achievement Level": "Above Standard",
                "Focus": "Reading",
                "Evidence": "used inferencing to identify themes",
                "Text Type": "persuasive text",
                "Learning Context": "advertising unit",
                "Point to Include in Comment": "",
                "English Focus Areas": "Inferencing, Text Structure",
                "Mathematics Proficiency Areas": "",
                "Mathematics Learning Habits": "",
                "Next Step Goals": "vary sentence openings"
            ],
            [
                "First Name": "Ari",
                "Last Name": "Kaur",
                "Year Level": "Year 5",
                "Subject": "The Arts",
                "Achievement Level": "At Standard",
                "Focus": "Music",
                "Evidence": "kept a steady rhythm",
                "Text Type": "performance",
                "Learning Context": "rhythm task",
                "Point to Include in Comment": "For The Arts or Technologies, keep the main subject in Subject and put the specific subject, such as Music, in Focus.",
                "English Focus Areas": "",
                "Mathematics Proficiency Areas": "",
                "Mathematics Learning Habits": "",
                "Next Step Goals": ""
            ]
        ]
    }

    public static func rosterTemplateCSV() throws -> String {
        try CSVParser.toCSV(rows: rosterTemplateRows(), headers: rosterHeaders)
    }

    public static func achievementResultsTemplateCSV() throws -> String {
        try CSVParser.toCSV(rows: achievementResultsTemplateRows(), headers: achievementResultsHeaders)
    }

    public static func filename(kind: CSVTemplateKind, format: ImportExportFormat) throws -> String {
        guard format == .csv || format == .xlsx || format == .xls else {
            throw ImportTemplateFileError.unsupportedFormat(format)
        }
        let stem = kind == .roster ? rosterFilenameStem : achievementResultsFilenameStem
        return "\(stem).\(format.rawValue)"
    }

    public static func sheetName(kind: CSVTemplateKind) -> String {
        kind == .roster ? "Class List" : "Report Details"
    }

    static func orderedRows(kind: CSVTemplateKind) -> [[String]] {
        let headers = kind == .roster ? rosterHeaders : achievementResultsHeaders
        let records = kind == .roster ? rosterTemplateRows() : achievementResultsTemplateRows()
        return [headers] + records.map { row in headers.map { row[$0] ?? "" } }
    }

    public static func templateDocument(kind: CSVTemplateKind, format: ImportExportFormat = .csv) throws -> CSVTemplateDocument {
        guard format == .csv else {
            throw CSVTemplateError.unsupportedFormat(format)
        }

        switch kind {
        case .roster:
            return CSVTemplateDocument(
                filename: rosterFilename,
                mimeType: csvMimeType,
                text: try rosterTemplateCSV()
            )
        case .achievementResults:
            return CSVTemplateDocument(
                filename: achievementResultsFilename,
                mimeType: csvMimeType,
                text: try achievementResultsTemplateCSV()
            )
        }
    }

}

public func prepareImportTemplateFile(
    kind: CSVTemplateKind,
    format: ImportExportFormat,
    directory: URL,
    fileManager: FileManager = .default
) throws -> PreparedImportTemplateFile {
    try prepareImportTemplateFile(
        kind: kind,
        format: format,
        directory: directory,
        fileManager: fileManager,
        verifyReadBack: { data, destination in
            try verifyImportTemplateData(data, kind: kind, format: format, destination: destination)
        }
    )
}

func prepareImportTemplateFile(
    kind: CSVTemplateKind,
    format: ImportExportFormat,
    directory: URL,
    fileManager: FileManager = .default,
    verifyReadBack: (Data, URL) throws -> Void
) throws -> PreparedImportTemplateFile {
    guard format == .csv || format == .xlsx || format == .xls else {
        throw ImportTemplateFileError.unsupportedFormat(format)
    }
    try ensureImportTemplateDirectory(directory, fileManager: fileManager)

    let data: Data
    do {
        switch format {
        case .csv:
            let text = kind == .roster
                ? try CSVTemplates.rosterTemplateCSV()
                : try CSVTemplates.achievementResultsTemplateCSV()
            data = Data(text.utf8)
        case .xlsx, .xls:
            data = try buildTabularWorkbookData(
                rows: CSVTemplates.orderedRows(kind: kind),
                sheetName: CSVTemplates.sheetName(kind: kind),
                format: format
            )
        case .docx, .backupJSON:
            throw ImportTemplateFileError.unsupportedFormat(format)
        }
    } catch let error as ImportTemplateFileError {
        throw error
    } catch {
        throw ImportTemplateFileError.generationFailed(error.localizedDescription)
    }

    let filename = try CSVTemplates.filename(kind: kind, format: format)
    let destination = availableFileDestination(directory: directory, preferredFilename: filename, fileManager: fileManager)
    do {
        try writeDataAtomicallyApplyingDefaultProtection(data, to: destination, fileManager: fileManager)
    } catch let writeError {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw ImportTemplateFileError.failedOutputCouldNotBeRemoved(destination)
        }
        throw writeError
    }

    do {
        let attributes = try fileManager.attributesOfItem(atPath: destination.path)
        let byteCount = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        guard byteCount > 0 else { throw ImportTemplateFileError.emptyWrittenFile(destination) }
        let readBack = try Data(contentsOf: destination)
        guard readBack == data else { throw ImportTemplateFileError.verificationFailed(destination) }
        try verifyReadBack(readBack, destination)
        return PreparedImportTemplateFile(
            url: destination,
            byteCount: byteCount,
            kind: kind,
            format: format
        )
    } catch let error as ImportTemplateFileError {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw ImportTemplateFileError.failedOutputCouldNotBeRemoved(destination)
        }
        throw error
    } catch {
        do {
            try removeFailedOutputIfPresent(destination, fileManager: fileManager)
        } catch {
            throw ImportTemplateFileError.failedOutputCouldNotBeRemoved(destination)
        }
        throw ImportTemplateFileError.verificationFailed(destination)
    }
}

private func ensureImportTemplateDirectory(_ directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw ImportTemplateFileError.invalidDirectory(directory.path)
        }
        try applyDefaultProtectionIfAvailable(to: directory, fileManager: fileManager)
        return
    }
    try createDirectoryApplyingDefaultProtection(directory, fileManager: fileManager)
}

private func verifyImportTemplateData(
    _ data: Data,
    kind: CSVTemplateKind,
    format: ImportExportFormat,
    destination: URL
) throws {
    switch format {
    case .csv:
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportTemplateFileError.verificationFailed(destination)
        }
        let parsed = try CSVParser.parseCSV(text)
        let expectedHeaders = kind == .roster ? CSVTemplates.rosterHeaders : CSVTemplates.achievementResultsHeaders
        let expectedRows = kind == .roster ? CSVTemplates.rosterTemplateRows() : CSVTemplates.achievementResultsTemplateRows()
        guard parsed.headers == expectedHeaders, parsed.rows == expectedRows else {
            throw ImportTemplateFileError.verificationFailed(destination)
        }
    case .xlsx, .xls:
        try verifyTabularWorkbookData(
            data,
            format: format,
            sheetName: CSVTemplates.sheetName(kind: kind),
            expectedRows: CSVTemplates.orderedRows(kind: kind)
        )
    case .docx, .backupJSON:
        throw ImportTemplateFileError.unsupportedFormat(format)
    }
}
