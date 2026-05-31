import CommenterDomain
import Foundation

public struct PreparedReviewWorkbookFile: Equatable, Sendable {
    public var url: URL
    public var byteCount: UInt64
    public var format: ImportExportFormat
    public var rowCount: Int

    public init(url: URL, byteCount: UInt64, format: ImportExportFormat, rowCount: Int) {
        self.url = url
        self.byteCount = byteCount
        self.format = format
        self.rowCount = rowCount
    }
}

public enum ReviewWorkbookFileError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)
    case invalidDirectory(String)
    case emptyWrittenFile(URL)
    case verificationFailed(URL)
    case legacyXLSGenerationFailed(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) review workbook writing is not implemented in this helper."
        case let .invalidDirectory(path):
            return "The review workbook destination is not a directory: \(path)"
        case let .emptyWrittenFile(url):
            return "The review workbook was written but is empty: \(url.lastPathComponent)"
        case let .verificationFailed(url):
            return "The review workbook was written but could not be verified: \(url.lastPathComponent)"
        case let .legacyXLSGenerationFailed(message):
            return "The legacy XLS review workbook could not be created: \(message)"
        }
    }
}

public func prepareReviewWorkbookFile(
    project: Project,
    format: ImportExportFormat,
    directory: URL,
    studentId: String? = nil,
    fileManager: FileManager = .default
) throws -> PreparedReviewWorkbookFile {
    guard format == .xlsx || format == .xls else {
        throw ReviewWorkbookFileError.unsupportedFormat(format)
    }

    try ensureWorkbookDirectory(directory, fileManager: fileManager)
    let rows = try reportReviewRows(project: project, studentId: studentId)
    let filename = try reportExportFilename(project: project, format: format, studentId: studentId)
    let destination = directory.appendingPathComponent(filename, isDirectory: false)
    let data: Data
    do {
        data = try buildReviewWorkbookData(rows: rows, format: format)
    } catch let error as LegacyXLSWorkbookError {
        throw ReviewWorkbookFileError.legacyXLSGenerationFailed(error.localizedDescription)
    }

    try data.write(to: destination, options: [.atomic])
    let byteCount = try verifiedWorkbookSize(url: destination, fileManager: fileManager)
    let readBack = try Data(contentsOf: destination)
    do {
        try verifyReviewWorkbook(readBack, format: format)
    } catch {
        throw ReviewWorkbookFileError.verificationFailed(destination)
    }

    return PreparedReviewWorkbookFile(url: destination, byteCount: byteCount, format: format, rowCount: rows.count)
}

private let requiredXLSXEntries: Set<String> = [
    "[Content_Types].xml",
    "_rels/.rels",
    "xl/workbook.xml",
    "xl/_rels/workbook.xml.rels",
    "xl/worksheets/sheet1.xml",
    "xl/styles.xml"
]

private func buildReviewWorkbookData(rows: [ReportReviewRow], format: ImportExportFormat) throws -> Data {
    switch format {
    case .xlsx:
        return try buildReviewWorkbookXLSX(rows: rows)
    case .xls:
        return try LegacyXLSWorkbookWriter.workbook(rows: [ReportReviewRow.headers] + rows.map(\.orderedValues), sheetName: "Reports")
    case .csv, .docx, .backupJSON:
        throw ReviewWorkbookFileError.unsupportedFormat(format)
    }
}

private func verifyReviewWorkbook(_ data: Data, format: ImportExportFormat) throws {
    switch format {
    case .xlsx:
        try OOXMLZipWriter.validateArchive(data, requiredEntries: requiredXLSXEntries)
    case .xls:
        try LegacyXLSWorkbookWriter.validateWorkbook(data, requiredSheetName: "Reports", requiredStrings: ReportReviewRow.headers)
    case .csv, .docx, .backupJSON:
        throw ReviewWorkbookFileError.unsupportedFormat(format)
    }
}

private func buildReviewWorkbookXLSX(rows: [ReportReviewRow]) throws -> Data {
    let worksheetRows = [ReportReviewRow.headers] + rows.map(\.orderedValues)
    let sheetXML = worksheetXML(sheetRows: worksheetRows)
    return try OOXMLZipWriter.archive(entries: [
        OOXMLZipEntry(path: "[Content_Types].xml", data: xmlData(contentTypesXML)),
        OOXMLZipEntry(path: "_rels/.rels", data: xmlData(rootRelationshipsXML)),
        OOXMLZipEntry(path: "xl/workbook.xml", data: xmlData(workbookXML)),
        OOXMLZipEntry(path: "xl/_rels/workbook.xml.rels", data: xmlData(workbookRelationshipsXML)),
        OOXMLZipEntry(path: "xl/worksheets/sheet1.xml", data: xmlData(sheetXML)),
        OOXMLZipEntry(path: "xl/styles.xml", data: xmlData(stylesXML))
    ])
}

private func ensureWorkbookDirectory(_ directory: URL, fileManager: FileManager) throws {
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory) {
        guard isDirectory.boolValue else {
            throw ReviewWorkbookFileError.invalidDirectory(directory.path)
        }
        return
    }
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
}

private func verifiedWorkbookSize(url: URL, fileManager: FileManager) throws -> UInt64 {
    let attributes = try fileManager.attributesOfItem(atPath: url.path)
    let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    guard size > 0 else {
        throw ReviewWorkbookFileError.emptyWrittenFile(url)
    }
    return size
}

private func xmlData(_ xml: String) -> Data {
    Data(xml.utf8)
}

private func worksheetXML(sheetRows: [[String]]) -> String {
    let rows = sheetRows.enumerated().map { rowIndex, values in
        let rowNumber = rowIndex + 1
        let cells = values.enumerated().map { columnIndex, value in
            let reference = "\(columnName(columnIndex + 1))\(rowNumber)"
            return #"<c r="\#(reference)" t="inlineStr"><is><t xml:space="preserve">\#(xmlEscape(value))</t></is></c>"#
        }.joined()
        return #"<row r="\#(rowNumber)">\#(cells)</row>"#
    }.joined()
    return xmlDeclaration + #"<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>\#(rows)</sheetData></worksheet>"#
}

private func columnName(_ oneBasedIndex: Int) -> String {
    var index = oneBasedIndex
    var name = ""
    while index > 0 {
        index -= 1
        let scalar = UnicodeScalar(65 + (index % 26))!
        name.insert(Character(scalar), at: name.startIndex)
        index /= 26
    }
    return name
}

private func xmlEscape(_ value: String) -> String {
    value
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private let xmlDeclaration = #"<?xml version="1.0" encoding="UTF-8" standalone="yes"?>"#

private let contentTypesXML = xmlDeclaration + #"""
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
"""#

private let rootRelationshipsXML = xmlDeclaration + #"""
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
"""#

private let workbookXML = xmlDeclaration + #"""
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Reports" sheetId="1" r:id="rId1"/></sheets></workbook>
"""#

private let workbookRelationshipsXML = xmlDeclaration + #"""
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
"""#

private let stylesXML = xmlDeclaration + #"""
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts><fills count="1"><fill><patternFill patternType="none"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs></styleSheet>
"""#
