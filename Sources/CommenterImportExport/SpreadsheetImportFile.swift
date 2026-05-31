import CoreXLSX
import Foundation
import OLEKit

public enum SpreadsheetImportFileError: LocalizedError, Equatable {
    case unsupportedFormat(String)
    case emptyFile
    case fileTooLarge(Int)
    case unreadableWorkbook(String)
    case emptyWorkbook(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(name):
            return "\(name) import supports CSV, XLSX, and XLS files only."
        case .emptyFile:
            return "The selected file is empty."
        case let .fileTooLarge(maximumKB):
            return "The selected file is too large. The maximum supported size is \(maximumKB) KB."
        case let .unreadableWorkbook(label):
            return "\(label) could not be opened as a workbook."
        case let .emptyWorkbook(label):
            return "The \(label) does not contain a non-empty worksheet."
        }
    }
}

public enum SpreadsheetImportFile {
    public static let maxImportBytes = 1024 * 1024

    public static func parseTabularImportFile(url: URL, label: String) throws -> CSVParseResult {
        let format = try importFormat(for: url, label: label)
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw SpreadsheetImportFileError.emptyFile }
        guard data.count <= maxImportBytes else {
            throw SpreadsheetImportFileError.fileTooLarge(maxImportBytes / 1024)
        }

        switch format {
        case .csv:
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                throw CSVParserError.empty(sourceLabel: label)
            }
            return try CSVParser.parseCSV(text)
        case .xlsx:
            return try parseXLSX(data, label: "\(label) workbook")
        case .xls:
            return try parseXLS(url, label: "\(label) workbook")
        case .docx, .backupJSON:
            throw SpreadsheetImportFileError.unsupportedFormat(label)
        }
    }

    public static func importFormat(for url: URL, label: String) throws -> ImportExportFormat {
        let name = url.lastPathComponent.lowercased()
        if name.hasSuffix(".csv") { return .csv }
        if name.hasSuffix(".xlsx") { return .xlsx }
        if name.hasSuffix(".xls") { return .xls }
        if name.range(of: #"\.(xlsm|xlsb|ods|numbers|pdf|docx)$"#, options: .regularExpression) != nil {
            throw SpreadsheetImportFileError.unsupportedFormat(label)
        }
        throw SpreadsheetImportFileError.unsupportedFormat(label)
    }

    public static func parseXLSX(_ data: Data, label: String) throws -> CSVParseResult {
        let file: XLSXFile
        do {
            file = try XLSXFile(data: data)
        } catch {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }

        do {
            let sharedStrings = try? file.parseSharedStrings()
            for workbook in try file.parseWorkbooks() {
                for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                    let worksheet = try file.parseWorksheet(at: path)
                    let rows = try worksheetRows(worksheet, sharedStrings: sharedStrings, label: label)
                    let normalized = normalizeWorksheetRows(rows)
                    if !normalized.isEmpty {
                        return try CSVParser.parseTabularRows(normalized, sourceLabel: label)
                    }
                }
            }
        } catch {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }

        throw SpreadsheetImportFileError.emptyWorkbook(label)
    }

    public static func parseXLS(_ url: URL, label: String) throws -> CSVParseResult {
        let stream: Data
        do {
            let ole = try OLEFile(url.path)
            guard let workbook = findOLEEntry(named: "Workbook", in: ole.root) ?? findOLEEntry(named: "Book", in: ole.root) else {
                throw LegacyXLSWorkbookError.missingWorkbookStream
            }
            stream = try ole.stream(workbook).readDataToEnd()
        } catch {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }

        let rows: [[String]]
        do {
            rows = try parseBIFFRows(stream)
        } catch {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        let normalized = normalizeWorksheetRows(rows)
        guard !normalized.isEmpty else {
            throw SpreadsheetImportFileError.emptyWorkbook(label)
        }
        return try CSVParser.parseTabularRows(normalized, sourceLabel: label)
    }
}

private func normalizeWorksheetRows(_ rawRows: [[String]]) -> [[String]] {
    let rows = rawRows.map { row -> [String] in
        var cells = row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        while cells.last == "" {
            cells.removeLast()
        }
        return cells
    }
    let nonEmpty = rows.filter { row in row.contains { !$0.isEmpty } }
    guard let headerLength = nonEmpty.first?.count, headerLength > 0 else { return [] }
    return nonEmpty.map { row in
        row.count < headerLength ? row + Array(repeating: "", count: headerLength - row.count) : row
    }
}

private func worksheetRows(_ worksheet: Worksheet, sharedStrings: SharedStrings?, label: String) throws -> [[String]] {
    try (worksheet.data?.rows ?? []).map { row in
        var cellsByIndex: [Int: String] = [:]
        for cell in row.cells {
            let column = columnIndex(from: cell.reference.column.description)
            cellsByIndex[column] = try worksheetCellValue(cell, sharedStrings: sharedStrings, label: label)
        }
        guard let maxColumn = cellsByIndex.keys.max() else { return [] }
        return (0...maxColumn).map { cellsByIndex[$0] ?? "" }
    }
}

private func worksheetCellValue(_ cell: Cell, sharedStrings: SharedStrings?, label: String) throws -> String {
    switch cell.type {
    case .some(.sharedString):
        guard let sharedStrings, let value = cell.stringValue(sharedStrings) else {
            throw SpreadsheetImportFileError.unreadableWorkbook(label)
        }
        return value
    case .some(.inlineStr):
        return cell.inlineString?.text ?? ""
    default:
        if let sharedStrings, let value = cell.stringValue(sharedStrings) {
            return value
        }
        return cell.value ?? ""
    }
}

private func columnIndex(from column: String) -> Int {
    var value = 0
    for scalar in column.uppercased().unicodeScalars {
        guard (65...90).contains(scalar.value) else { return 0 }
        value = value * 26 + Int(scalar.value - 64)
    }
    return max(0, value - 1)
}

private func findOLEEntry(named name: String, in entry: DirectoryEntry) -> DirectoryEntry? {
    if entry.name == name {
        return entry
    }
    for child in entry.children {
        if let match = findOLEEntry(named: name, in: child) {
            return match
        }
    }
    return nil
}

private func parseBIFFRows(_ stream: Data) throws -> [[String]] {
    var sharedStrings: [String] = []
    var cells: [Int: [Int: String]] = [:]
    var offset = 0
    while offset + 4 <= stream.count {
        let id = stream.uint16LE(at: offset)
        let length = Int(stream.uint16LE(at: offset + 2))
        let payloadStart = offset + 4
        let payloadEnd = payloadStart + length
        guard payloadEnd <= stream.count else { throw LegacyXLSWorkbookError.invalidWorkbookStream }
        let payload = Data(stream[payloadStart..<payloadEnd])

        switch id {
        case 0x00fc:
            sharedStrings = decodeSST(payload)
        case 0x0204:
            if payload.count >= 9, let value = decodeXLUnicodeString(payload, offset: 6) {
                cells[Int(payload.uint16LE(at: 0)), default: [:]][Int(payload.uint16LE(at: 2))] = value
            }
        case 0x00fd:
            if payload.count >= 10 {
                let index = Int(payload.uint32LE(at: 6))
                if sharedStrings.indices.contains(index) {
                    cells[Int(payload.uint16LE(at: 0)), default: [:]][Int(payload.uint16LE(at: 2))] = sharedStrings[index]
                }
            }
        case 0x0203:
            if payload.count >= 14 {
                let value = payload.doubleLE(at: 6)
                cells[Int(payload.uint16LE(at: 0)), default: [:]][Int(payload.uint16LE(at: 2))] = numberString(value)
            }
        case 0x000a:
            break
        default:
            break
        }
        offset = payloadEnd
    }

    guard let maxRow = cells.keys.max() else { return [] }
    return (0...maxRow).map { rowIndex in
        let row = cells[rowIndex] ?? [:]
        guard let maxColumn = row.keys.max() else { return [] }
        return (0...maxColumn).map { row[$0] ?? "" }
    }
}

private func decodeSST(_ payload: Data) -> [String] {
    guard payload.count >= 8 else { return [] }
    let count = Int(payload.uint32LE(at: 4))
    var strings: [String] = []
    var offset = 8
    while offset < payload.count, strings.count < count {
        guard let decoded = decodeXLUnicodeStringWithLength(payload, offset: offset) else { break }
        strings.append(decoded.value)
        offset = decoded.nextOffset
    }
    return strings
}

private func decodeXLUnicodeString(_ payload: Data, offset: Int) -> String? {
    decodeXLUnicodeStringWithLength(payload, offset: offset)?.value
}

private func decodeXLUnicodeStringWithLength(_ payload: Data, offset: Int) -> (value: String, nextOffset: Int)? {
    guard offset + 3 <= payload.count else { return nil }
    let length = Int(payload.uint16LE(at: offset))
    let flags = payload[offset + 2]
    let start = offset + 3
    if flags & 0x01 == 0 {
        guard start + length <= payload.count else { return nil }
        return (String(bytes: payload[start..<start + length], encoding: .utf8) ?? "", start + length)
    }
    guard start + (length * 2) <= payload.count else { return nil }
    let units = stride(from: start, to: start + (length * 2), by: 2).map { payload.uint16LE(at: $0) }
    return (String(decoding: units, as: UTF16.self), start + (length * 2))
}

private func numberString(_ value: Double) -> String {
    value.rounded() == value ? String(Int64(value)) : String(value)
}

private extension Data {
    func uint16LE(at offset: Int) -> UInt16 {
        UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func uint32LE(at offset: Int) -> UInt32 {
        UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }

    func doubleLE(at offset: Int) -> Double {
        let bits = UInt64(self[offset])
            | (UInt64(self[offset + 1]) << 8)
            | (UInt64(self[offset + 2]) << 16)
            | (UInt64(self[offset + 3]) << 24)
            | (UInt64(self[offset + 4]) << 32)
            | (UInt64(self[offset + 5]) << 40)
            | (UInt64(self[offset + 6]) << 48)
            | (UInt64(self[offset + 7]) << 56)
        return Double(bitPattern: bits)
    }
}
