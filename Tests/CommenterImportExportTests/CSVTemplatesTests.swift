@testable import CommenterImportExport
import Foundation
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
            "General Comment Point",
            "Private Teacher Note"
        ])
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0]["First Name"], "John")
        XCTAssertEqual(rows[0]["Year Level"], "Year 5")
        XCTAssertEqual(rows[0]["General Comment Point"], "Uses feedback thoughtfully")
        XCTAssertEqual(rows[0]["Private Teacher Note"], "Private note; not included in reports")

        let csv = try CSVTemplates.rosterTemplateCSV()
        let headerLine = try XCTUnwrap(csv.components(separatedBy: "\r\n").first)
        XCTAssertEqual(headerLine, "First Name,Last Name,Year Level,Gender,Attitude,General Comment Point,Private Teacher Note")
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
            "Point to Include in Comment",
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

        let csv = try CSVTemplates.achievementResultsTemplateCSV()
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
        XCTAssertEqual(parsed.rows[2]["Point to Include in Comment"], rows[2]["Point to Include in Comment"])
    }

    func testTemplateDocumentsReturnCSVOnlyWithTruthfulMetadata() throws {
        let roster = try CSVTemplates.templateDocument(kind: .roster, format: .csv)
        XCTAssertEqual(roster.filename, "report_writer_class_list_template.csv")
        XCTAssertEqual(roster.mimeType, "text/csv;charset=utf-8")
        XCTAssertEqual(roster.text, try CSVTemplates.rosterTemplateCSV())

        let results = try CSVTemplates.templateDocument(kind: .achievementResults, format: .csv)
        XCTAssertEqual(results.filename, "report_writer_report_details_template.csv")
        XCTAssertEqual(results.mimeType, "text/csv;charset=utf-8")
        XCTAssertEqual(results.text, try CSVTemplates.achievementResultsTemplateCSV())

        XCTAssertThrowsError(try CSVTemplates.templateDocument(kind: .roster, format: .xlsx)) { error in
            XCTAssertEqual(error as? CSVTemplateError, .unsupportedFormat(.xlsx))
        }
        XCTAssertThrowsError(try CSVTemplates.templateDocument(kind: .achievementResults, format: .xls)) { error in
            XCTAssertEqual(error as? CSVTemplateError, .unsupportedFormat(.xls))
        }
    }

    func testPreparedImportTemplatesCoverBothKindsAndAllLiveFormats() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSTemplateTests-\(UUID().uuidString)", isDirectory: true)
        let cases: [(CSVTemplateKind, ImportExportFormat, String, [String], Int)] = [
            (.roster, .csv, "report_writer_class_list_template.csv", CSVTemplates.rosterHeaders, 2),
            (.roster, .xlsx, "report_writer_class_list_template.xlsx", CSVTemplates.rosterHeaders, 2),
            (.roster, .xls, "report_writer_class_list_template.xls", CSVTemplates.rosterHeaders, 2),
            (.achievementResults, .csv, "report_writer_report_details_template.csv", CSVTemplates.achievementResultsHeaders, 3),
            (.achievementResults, .xlsx, "report_writer_report_details_template.xlsx", CSVTemplates.achievementResultsHeaders, 3),
            (.achievementResults, .xls, "report_writer_report_details_template.xls", CSVTemplates.achievementResultsHeaders, 3)
        ]

        for (kind, format, expectedFilename, expectedHeaders, expectedRowCount) in cases {
            let prepared = try prepareImportTemplateFile(
                kind: kind,
                format: format,
                directory: root
            )

            XCTAssertEqual(prepared.url.lastPathComponent, expectedFilename)
            XCTAssertEqual(prepared.kind, kind)
            XCTAssertEqual(prepared.format, format)
            XCTAssertGreaterThan(prepared.byteCount, 0)
            let parsed = try SpreadsheetImportFile.parseTabularImportFile(
                url: prepared.url,
                label: kind == .roster ? "Roster" : "Results"
            )
            XCTAssertEqual(parsed.headers, expectedHeaders)
            XCTAssertEqual(parsed.rows.count, expectedRowCount)
        }
    }

    func testPreparedImportTemplatesNeverOverwriteAnExistingDownload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSTemplateCollisionTests-\(UUID().uuidString)", isDirectory: true)
        let first = try prepareImportTemplateFile(kind: .roster, format: .xlsx, directory: root)
        let firstData = try Data(contentsOf: first.url)

        let second = try prepareImportTemplateFile(kind: .roster, format: .xlsx, directory: root)

        XCTAssertEqual(first.url.lastPathComponent, "report_writer_class_list_template.xlsx")
        XCTAssertEqual(second.url.lastPathComponent, "report_writer_class_list_template-2.xlsx")
        XCTAssertEqual(try Data(contentsOf: first.url), firstData)
    }

    func testPreparedImportTemplateRemovesOutputWhenVerificationFails() throws {
        enum ExpectedFailure: Error { case failed }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSTemplateFailureTests-\(UUID().uuidString)", isDirectory: true)

        XCTAssertThrowsError(try prepareImportTemplateFile(
            kind: .achievementResults,
            format: .csv,
            directory: root,
            verifyReadBack: { _, _ in throw ExpectedFailure.failed }
        )) { error in
            XCTAssertEqual(
                error as? ImportTemplateFileError,
                .verificationFailed(root.appendingPathComponent("report_writer_report_details_template.csv"))
            )
        }
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: root.appendingPathComponent("report_writer_report_details_template.csv").path
        ))
    }

    func testPreparedImportTemplateRejectsUnsupportedFormatsAndNonDirectoryDestinations() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSTemplateDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: fileURL)

        XCTAssertThrowsError(try prepareImportTemplateFile(kind: .roster, format: .docx, directory: root)) { error in
            XCTAssertEqual(error as? ImportTemplateFileError, .unsupportedFormat(.docx))
        }
        XCTAssertThrowsError(try prepareImportTemplateFile(kind: .roster, format: .csv, directory: fileURL)) { error in
            XCTAssertEqual(error as? ImportTemplateFileError, .invalidDirectory(fileURL.path))
        }
    }
}
