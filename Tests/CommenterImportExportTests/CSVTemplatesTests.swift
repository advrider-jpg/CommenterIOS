import CommenterImportExport
import XCTest

final class CSVTemplatesTests: XCTestCase {
    func testRosterTemplateRowsUseTeacherFacingHeadersAndValues() throws {
        let rows = CSVTemplates.rosterTemplateRows()

        XCTAssertEqual(CSVTemplates.rosterHeaders, [
            "First Name",
            "Last Name",
            "Year Level",
            "Gender",
            "Attitude",
            "Private Teacher Note"
        ])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["First Name"], "John")
        XCTAssertEqual(rows[0]["Year Level"], "Year 5")
        XCTAssertEqual(rows[0]["Private Teacher Note"], "Private note; not included in reports")

        let csv = CSVTemplates.rosterTemplateCSV()
        let headerLine = try XCTUnwrap(csv.components(separatedBy: "\r\n").first)
        XCTAssertEqual(headerLine, "First Name,Last Name,Year Level,Gender,Attitude,Private Teacher Note")
        XCTAssertFalse(headerLine.contains("Comments"))
        XCTAssertFalse(headerLine.contains("Internal ID"))
        XCTAssertFalse(headerLine.contains("Student Code"))

        let parsed = try CSVParser.parseCSV(csv)
        XCTAssertEqual(parsed.headers, CSVTemplates.rosterHeaders)
        XCTAssertEqual(parsed.rows.count, 2)
    }

    func testAchievementResultsTemplateRowsUseCurrentTeacherFacingHeaders() throws {
        let rows = CSVTemplates.achievementResultsTemplateRows()

        XCTAssertEqual(CSVTemplates.achievementResultsHeaders, [
            "First Name",
            "Last Name",
            "Year Level",
            "Subject",
            "Achievement Level",
            "Focus",
            "Evidence",
            "Text Type",
            "Learning Context",
            "Optional Report Note",
            "English Focus Areas",
            "Mathematics Proficiency Areas",
            "Mathematics Learning Habits",
            "Next Step Goals"
        ])
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[0]["Subject"], "Mathematics")
        XCTAssertEqual(rows[1]["English Focus Areas"], "Inferencing, Text Structure")
        XCTAssertEqual(rows[2]["Subject"], "The Arts")
        XCTAssertEqual(rows[2]["Focus"], "Music")

        let csv = CSVTemplates.achievementResultsTemplateCSV()
        let headerLine = try XCTUnwrap(csv.components(separatedBy: "\r\n").first)
        XCTAssertEqual(headerLine, CSVTemplates.achievementResultsHeaders.joined(separator: ","))
        XCTAssertFalse(headerLine.contains("Comments"))
        XCTAssertFalse(headerLine.contains("English Focus Tags"))
        XCTAssertFalse(headerLine.contains("Math Mindsets"))
        XCTAssertFalse(headerLine.contains("Internal"))
        XCTAssertFalse(headerLine.contains("Concrete Subject"))

        let parsed = try CSVParser.parseCSV(csv)
        XCTAssertEqual(parsed.headers, CSVTemplates.achievementResultsHeaders)
        XCTAssertEqual(parsed.rows.count, 3)
        XCTAssertEqual(parsed.rows[0]["Mathematics Proficiency Areas"], "Understanding, Fluency")
        XCTAssertEqual(parsed.rows[2]["Optional Report Note"], rows[2]["Optional Report Note"])
    }

    func testTemplateDocumentsReturnCSVOnlyWithTruthfulMetadata() throws {
        let roster = try CSVTemplates.templateDocument(kind: .roster, format: .csv)
        XCTAssertEqual(roster.filename, "commenter_roster_template.csv")
        XCTAssertEqual(roster.mimeType, "text/csv;charset=utf-8")
        XCTAssertEqual(roster.text, CSVTemplates.rosterTemplateCSV())

        let results = try CSVTemplates.templateDocument(kind: .achievementResults, format: .csv)
        XCTAssertEqual(results.filename, "commenter_results_template.csv")
        XCTAssertEqual(results.mimeType, "text/csv;charset=utf-8")
        XCTAssertEqual(results.text, CSVTemplates.achievementResultsTemplateCSV())

        XCTAssertThrowsError(try CSVTemplates.templateDocument(kind: .roster, format: .xlsx)) { error in
            XCTAssertEqual(error as? CSVTemplateError, .unsupportedFormat(.xlsx))
        }
        XCTAssertThrowsError(try CSVTemplates.templateDocument(kind: .achievementResults, format: .xls)) { error in
            XCTAssertEqual(error as? CSVTemplateError, .unsupportedFormat(.xls))
        }
    }
}
