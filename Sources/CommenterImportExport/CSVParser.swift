import CodableCSV
import Foundation

public struct CSVParseResult: Equatable, Sendable {
    public var headers: [String]
    public var rows: [[String: String]]

    public init(headers: [String], rows: [[String: String]]) {
        self.headers = headers
        self.rows = rows
    }
}

public enum CSVParserError: LocalizedError, Equatable {
    case empty(sourceLabel: String)
    case blankHeader(sourceLabel: String)
    case duplicateHeader(sourceLabel: String, header: String)
    case missingDataRows(sourceLabel: String)
    case tooManyRows(sourceLabel: String, count: Int, maximum: Int)
    case tooManyColumns(sourceLabel: String, count: Int, maximum: Int)
    case tooManyCells(sourceLabel: String, maximum: Int)
    case cellTextTooLong(sourceLabel: String, row: Int, maximum: Int)
    case rowWidthMismatch(sourceLabel: String, row: Int, expectedColumns: Int)
    case unterminatedQuotedField
    case malformed
    case couldNotEncode

    public var errorDescription: String? {
        switch self {
        case let .empty(sourceLabel):
            return "The \(sourceLabel) is empty."
        case let .blankHeader(sourceLabel):
            return "The \(sourceLabel) header row contains an empty column name."
        case let .duplicateHeader(sourceLabel, header):
            return "The \(sourceLabel) header \"\(header)\" appears more than once."
        case let .missingDataRows(sourceLabel):
            return "The \(sourceLabel) does not contain any data rows."
        case let .tooManyRows(sourceLabel, count, maximum):
            return "The \(sourceLabel) has \(count) rows; the maximum supported import is \(maximum) rows."
        case let .tooManyColumns(sourceLabel, count, maximum):
            return "The \(sourceLabel) has \(count) columns; the maximum supported import is \(maximum) columns."
        case let .tooManyCells(sourceLabel, maximum):
            return "The \(sourceLabel) contains more than the supported maximum of \(maximum) cells."
        case let .cellTextTooLong(sourceLabel, row, maximum):
            return "The \(sourceLabel) contains a cell longer than \(maximum) characters at row \(row)."
        case let .rowWidthMismatch(sourceLabel, row, expectedColumns):
            let label = expectedColumns == 1 ? "column" : "columns"
            return "The \(sourceLabel) has a row with missing or incorrect information at row \(row); expected \(expectedColumns) \(label)."
        case .unterminatedQuotedField:
            return "The CSV file has an unterminated quoted field."
        case .malformed:
            return "The CSV file is malformed and could not be read."
        case .couldNotEncode:
            return "The CSV file could not be encoded. No export file was created."
        }
    }
}

public enum CSVParser {
    public static let maxImportRows = 500
    public static let maxImportColumns = 256
    public static let maxImportCells = 250_000
    public static let maxCellTextCharacters = 32_768

    public static func normalizeHeader(_ value: String) -> String {
        value
            .lowercased()
            .unicodeScalars
            .filter { scalar in
                (97...122).contains(scalar.value) || (48...57).contains(scalar.value)
            }
            .map(String.init)
            .joined()
    }

    public static func findKey(in row: [String: String], matching target: String) -> String? {
        let normalizedTarget = normalizeHeader(target)
        return row.keys.first { normalizeHeader($0) == normalizedTarget }
    }

    public static func value(in row: [String: String], matching target: String) -> String {
        guard let key = findKey(in: row, matching: target) else { return "" }
        return (row[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func parseCSV(_ text: String, maxRows: Int = maxImportRows) throws -> CSVParseResult {
        if let error = unquotedRowWidthMismatch(in: text) {
            throw error
        }

        let normalizedText = normalizeUnquotedRowBreaks(text)
        do {
            let parsed = try CSVReader.decode(input: normalizedText, configuration: csvReaderConfiguration())
            return try parseTabularRows(parsed.rows, sourceLabel: "CSV file", maxRows: maxRows)
        } catch let error as CSVParserError {
            throw error
        } catch {
            if hasUnterminatedQuotedField(normalizedText) {
                throw CSVParserError.unterminatedQuotedField
            }
            throw CSVParserError.malformed
        }
    }

    public static func parseTabularRows(_ rows: [[String]], sourceLabel: String = "file", maxRows: Int = maxImportRows) throws -> CSVParseResult {
        let normalizedRows = rows.map { row in
            row.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        let nonEmptyRows = normalizedRows.filter { row in
            row.contains { !$0.isEmpty }
        }

        guard !nonEmptyRows.isEmpty else {
            throw CSVParserError.empty(sourceLabel: sourceLabel)
        }

        let headers = nonEmptyRows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if headers.contains(where: { $0.isEmpty || normalizeHeader($0).isEmpty }) {
            throw CSVParserError.blankHeader(sourceLabel: sourceLabel)
        }
        guard headers.count <= maxImportColumns else {
            throw CSVParserError.tooManyColumns(sourceLabel: sourceLabel, count: headers.count, maximum: maxImportColumns)
        }

        var seenHeaders: Set<String> = []
        for header in headers {
            let normalized = normalizeHeader(header)
            if seenHeaders.contains(normalized) {
                throw CSVParserError.duplicateHeader(sourceLabel: sourceLabel, header: header)
            }
            seenHeaders.insert(normalized)
        }

        let dataRows = Array(nonEmptyRows.dropFirst())
        guard !dataRows.isEmpty else {
            throw CSVParserError.missingDataRows(sourceLabel: sourceLabel)
        }

        if dataRows.count > maxRows {
            throw CSVParserError.tooManyRows(sourceLabel: sourceLabel, count: dataRows.count, maximum: maxRows)
        }
        var cellCount = 0
        for row in nonEmptyRows {
            guard row.count <= maxImportColumns else {
                throw CSVParserError.tooManyColumns(sourceLabel: sourceLabel, count: row.count, maximum: maxImportColumns)
            }
            guard row.count <= maxImportCells - cellCount else {
                throw CSVParserError.tooManyCells(sourceLabel: sourceLabel, maximum: maxImportCells)
            }
            cellCount += row.count
        }

        for (index, cells) in dataRows.enumerated() where cells.count != headers.count {
            throw CSVParserError.rowWidthMismatch(sourceLabel: sourceLabel, row: index + 2, expectedColumns: headers.count)
        }
        for (rowIndex, cells) in nonEmptyRows.enumerated() where cells.contains(where: { $0.utf16.count > maxCellTextCharacters }) {
            throw CSVParserError.cellTextTooLong(sourceLabel: sourceLabel, row: rowIndex + 1, maximum: maxCellTextCharacters)
        }

        let dictionaries = dataRows.map { cells in
            Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, cells[index])
            })
        }

        return CSVParseResult(headers: headers, rows: dictionaries)
    }

    public static func toCSV(rows: [[String: String]], headers explicitHeaders: [String]? = nil) throws -> String {
        let headers: [String]
        if let explicitHeaders {
            headers = explicitHeaders
        } else {
            headers = rows.reduce(into: []) { ordered, row in
                for key in row.keys.sorted() where !ordered.contains(key) {
                    ordered.append(key)
                }
            }
        }
        guard !headers.isEmpty else {
            if rows.isEmpty { return "" }
            throw CSVParserError.couldNotEncode
        }

        let table = [headers.map(formulaGuard)] + rows.map { row in
            headers.map { formulaGuard(row[$0] ?? "") }
        }
        do {
            return try CSVWriter.encode(rows: table, into: String.self, configuration: csvWriterConfiguration())
        } catch {
            throw CSVParserError.couldNotEncode
        }
    }

    private static func formulaGuard(_ value: String) -> String {
        value.range(of: #"^\s*[=+\-@]"#, options: .regularExpression) == nil ? value : "'\(value)"
    }

    private static func csvReaderConfiguration() -> CSVReader.Configuration {
        var configuration = CSVReader.Configuration()
        configuration.headerStrategy = .none
        configuration.delimiters.row = .standard
        configuration.presample = true
        return configuration
    }

    private static func normalizeUnquotedRowBreaks(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        var insideQuotedField = false

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if character == "\"" {
                if insideQuotedField, next < text.endIndex, text[next] == "\"" {
                    output.append(character)
                    output.append(text[next])
                    index = text.index(after: next)
                    continue
                }
                insideQuotedField.toggle()
                output.append(character)
            } else if !insideQuotedField, character == "\r" {
                if next < text.endIndex, text[next] == "\n" {
                    output.append("\r\n")
                    index = text.index(after: next)
                    continue
                }
                output.append("\r\n")
            } else if !insideQuotedField, character == "\n" {
                output.append("\r\n")
            } else {
                output.append(character)
            }

            index = next
        }

        return output
    }

    private static func hasUnterminatedQuotedField(_ text: String) -> Bool {
        var index = text.startIndex
        var insideQuotedField = false

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if character == "\"" {
                if insideQuotedField, next < text.endIndex, text[next] == "\"" {
                    index = text.index(after: next)
                    continue
                }
                insideQuotedField.toggle()
            }

            index = next
        }

        return insideQuotedField
    }

    private static func unquotedRowWidthMismatch(in text: String) -> CSVParserError? {
        guard !text.contains("\"") else { return nil }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let rows = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        let parsedRows = rows.enumerated().compactMap { index, row -> (number: Int, cells: [String])? in
            let cells = row.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard cells.contains(where: { !$0.isEmpty }) else { return nil }
            return (index + 1, cells)
        }

        guard let header = parsedRows.first, parsedRows.count > 1 else { return nil }
        for row in parsedRows.dropFirst() where row.cells.count != header.cells.count {
            return .rowWidthMismatch(sourceLabel: "CSV file", row: row.number, expectedColumns: header.cells.count)
        }

        return nil
    }

    private static func csvWriterConfiguration() -> CSVWriter.Configuration {
        var configuration = CSVWriter.Configuration()
        configuration.delimiters.row = "\r\n"
        return configuration
    }
}
