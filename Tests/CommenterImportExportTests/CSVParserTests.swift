import CommenterImportExport
import XCTest

final class CSVParserTests: XCTestCase {
    func testParsesQuotedCSVAndTrimsTabularCells() throws {
        let parsed = try CSVParser.parseCSV("""
        First Name, Last Name,Year Level,Comments\r
        Ava, Ng ,Year 5,"=""not a formula"", keeps comma"\r
        Ben,Stone,Year 6,"Line one\r
        Line two"
        """)

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name", "Year Level", "Comments"])
        XCTAssertEqual(parsed.rows.count, 2)
        XCTAssertEqual(parsed.rows[0]["First Name"], "Ava")
        XCTAssertEqual(parsed.rows[0]["Last Name"], "Ng")
        XCTAssertEqual(parsed.rows[0]["Comments"], "=\"not a formula\", keeps comma")
        XCTAssertEqual(parsed.rows[1]["Comments"], "Line one\r\nLine two")
    }

    func testSupportsLFCRAndCRLFRowBreaks() throws {
        let lfOnly = try CSVParser.parseCSV("First Name,Last Name\nBen,Stone")
        XCTAssertEqual(lfOnly.rows[0]["Last Name"], "Stone")

        let crOnly = try CSVParser.parseCSV("First Name,Last Name\rCara,Lee")
        XCTAssertEqual(crOnly.rows[0]["First Name"], "Cara")

        let crlf = try CSVParser.parseCSV("First Name,Last Name\r\nAva,Ng")
        XCTAssertEqual(crlf.rows[0]["First Name"], "Ava")
    }

    func testUsesFirstNonEmptyRowAsHeaderAndSkipsBlankRows() throws {
        let parsed = try CSVParser.parseCSV("\n\n  ,  \n First Name , Last Name \n Ava , Ng \n\n")

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name"])
        XCTAssertEqual(parsed.rows, [["First Name": "Ava", "Last Name": "Ng"]])
    }

    func testRejectsMalformedCSVBeforeDomainImport() {
        XCTAssertThrowsError(try CSVParser.parseCSV("")) { error in
            XCTAssertEqual(error as? CSVParserError, .empty(sourceLabel: "CSV file"))
        }

        XCTAssertThrowsError(try CSVParser.parseTabularRows([["First Name", ""]], sourceLabel: "Roster")) { error in
            XCTAssertEqual(error as? CSVParserError, .blankHeader(sourceLabel: "Roster"))
        }

        XCTAssertThrowsError(try CSVParser.parseTabularRows([["!!!"], ["value"]], sourceLabel: "Roster")) { error in
            XCTAssertEqual(error as? CSVParserError, .blankHeader(sourceLabel: "Roster"))
        }

        XCTAssertThrowsError(try CSVParser.parseCSV("First Name,First-Name\nAva,Ng")) { error in
            XCTAssertEqual(error as? CSVParserError, .duplicateHeader(sourceLabel: "CSV file", header: "First-Name"))
        }

        XCTAssertThrowsError(try CSVParser.parseCSV("First Name,Last Name\nAva,Ng,extra")) { error in
            XCTAssertEqual(error as? CSVParserError, .rowWidthMismatch(sourceLabel: "CSV file", row: 2, expectedColumns: 2))
        }

        XCTAssertThrowsError(try CSVParser.parseCSV("First Name,Last Name\n\"unterminated")) { error in
            XCTAssertEqual(error as? CSVParserError, .unterminatedQuotedField)
        }

        XCTAssertThrowsError(try CSVParser.parseCSV("First Name,Last Name\nAva,\"Ng\"trailing")) { error in
            XCTAssertEqual(error as? CSVParserError, .malformed)
        }
    }

    func testRejectsUnboundedColumnAndCellTextInputs() {
        let tooManyHeaders = (0...CSVParser.maxImportColumns).map { "Column \($0)" }
        let tooManyValues = Array(repeating: "value", count: tooManyHeaders.count)
        XCTAssertThrowsError(try CSVParser.parseTabularRows([tooManyHeaders, tooManyValues], sourceLabel: "Roster")) { error in
            XCTAssertEqual(
                error as? CSVParserError,
                .tooManyColumns(sourceLabel: "Roster", count: CSVParser.maxImportColumns + 1, maximum: CSVParser.maxImportColumns)
            )
        }

        XCTAssertThrowsError(try CSVParser.parseTabularRows(
            [["Name"], [String(repeating: "x", count: CSVParser.maxCellTextCharacters + 1)]],
            sourceLabel: "Roster"
        )) { error in
            XCTAssertEqual(
                error as? CSVParserError,
                .cellTextTooLong(sourceLabel: "Roster", row: 2, maximum: CSVParser.maxCellTextCharacters)
            )
        }

        XCTAssertThrowsError(try CSVParser.parseTabularRows(
            [["Name"], [String(repeating: "😀", count: (CSVParser.maxCellTextCharacters / 2) + 1)]],
            sourceLabel: "Roster"
        )) { error in
            XCTAssertEqual(
                error as? CSVParserError,
                .cellTextTooLong(sourceLabel: "Roster", row: 2, maximum: CSVParser.maxCellTextCharacters)
            )
        }
    }

    func testRejectsMissingDataRowsAndRowsBeyondConfiguredImportLimit() {
        XCTAssertEqual(CSVParser.maxImportRows, 500)
        XCTAssertThrowsError(try CSVParser.parseCSV("First Name,Last Name\n\n")) { error in
            XCTAssertEqual(error as? CSVParserError, .missingDataRows(sourceLabel: "CSV file"))
        }

        let rows = (0...CSVParser.maxImportRows).map { "Ava \($0)" }.joined(separator: "\n")
        XCTAssertThrowsError(try CSVParser.parseCSV("First Name\n\(rows)")) { error in
            XCTAssertEqual(
                error as? CSVParserError,
                .tooManyRows(sourceLabel: "CSV file", count: CSVParser.maxImportRows + 1, maximum: CSVParser.maxImportRows)
            )
        }
    }

    func testHeaderNormalizationIsCaseAndPunctuationInsensitive() {
        XCTAssertEqual(CSVParser.normalizeHeader(" Achievement Level "), "achievementlevel")
        XCTAssertEqual(CSVParser.normalizeHeader("Achievement-Level"), "achievementlevel")
    }

    func testFindsHeaderAliasesAndSerializesFormulaSafeCSV() throws {
        let parsed = try CSVParser.parseCSV("Achievement Level,Notes\nAt Standard,Ready")

        XCTAssertEqual(CSVParser.findKey(in: parsed.rows[0], matching: "AchievementLevel"), "Achievement Level")
        XCTAssertEqual(CSVParser.value(in: parsed.rows[0], matching: "notes"), "Ready")

        let csv = try CSVParser.toCSV(rows: [["=Name": "=SUM(A1:A2)", "Notes": "Line one\nLine two"]], headers: ["=Name", "Notes"])
        XCTAssertTrue(csv.hasPrefix("'=Name,Notes"))
        XCTAssertTrue(csv.contains("'=SUM(A1:A2)"))
        XCTAssertTrue(csv.contains("Line one"))
        XCTAssertTrue(csv.contains("Line two"))

        XCTAssertThrowsError(try CSVParser.toCSV(rows: [["Name": "Ava"]], headers: [])) { error in
            XCTAssertEqual(error as? CSVParserError, .couldNotEncode)
        }
    }
}
