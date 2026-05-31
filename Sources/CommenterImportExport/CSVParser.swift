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
    case rowWidthMismatch(sourceLabel: String, row: Int, expectedColumns: Int)
    case unterminatedQuotedField

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
        case let .rowWidthMismatch(sourceLabel, row, expectedColumns):
            let label = expectedColumns == 1 ? "column" : "columns"
            return "The \(sourceLabel) has a row with missing or incorrect information at row \(row); expected \(expectedColumns) \(label)."
        case .unterminatedQuotedField:
            return "The CSV file has an unterminated quoted field."
        }
    }
}

public enum CSVParser {
    public static let maxImportRows = 500

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

    public static func parseCSV(_ text: String) throws -> CSVParseResult {
        do {
            let parsed = try CSVReader.decode(input: text, configuration: csvReaderConfiguration())
            return try parseTabularRows(parsed.rows, sourceLabel: "CSV file")
        } catch let error as CSVParserError {
            throw error
        } catch {
            throw CSVParserError.unterminatedQuotedField
        }
    }

    public static func parseTabularRows(_ rows: [[String]], sourceLabel: String = "file") throws -> CSVParseResult {
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
        if headers.contains(where: { $0.isEmpty }) {
            throw CSVParserError.blankHeader(sourceLabel: sourceLabel)
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

        if dataRows.count > maxImportRows {
            throw CSVParserError.tooManyRows(sourceLabel: sourceLabel, count: dataRows.count, maximum: maxImportRows)
        }

        for (index, cells) in dataRows.enumerated() where cells.count != headers.count {
            throw CSVParserError.rowWidthMismatch(sourceLabel: sourceLabel, row: index + 2, expectedColumns: headers.count)
        }

        let dictionaries = dataRows.map { cells in
            Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, cells[index])
            })
        }

        return CSVParseResult(headers: headers, rows: dictionaries)
    }

    public static func toCSV(rows: [[String: String]]) -> String {
        guard let first = rows.first else { return "" }
        let headers = Array(first.keys)
        let table = [headers] + rows.map { row in
            headers.map { formulaGuard(row[$0] ?? "") }
        }
        return (try? CSVWriter.encode(rows: table, into: String.self, configuration: csvWriterConfiguration())) ?? ""
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

    private static func csvWriterConfiguration() -> CSVWriter.Configuration {
        var configuration = CSVWriter.Configuration()
        configuration.delimiters.row = "\r\n"
        return configuration
    }
}
