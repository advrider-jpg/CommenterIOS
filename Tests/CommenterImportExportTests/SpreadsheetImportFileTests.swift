@testable import CommenterImportExport
import Foundation
import XCTest

final class SpreadsheetImportFileTests: XCTestCase {
    func testParseTabularImportFileParsesCSVFileThroughSharedValidation() throws {
        let url = try writeTemporaryFile(
            name: "roster.csv",
            data: Data("First Name,Last Name,Year Level\nAva,Ng,Year 5".utf8)
        )

        let parsed = try SpreadsheetImportFile.parseTabularImportFile(url: url, label: "Roster")

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name", "Year Level"])
        XCTAssertEqual(parsed.rows, [["First Name": "Ava", "Last Name": "Ng", "Year Level": "Year 5"]])
    }

    func testParseTabularImportFileParsesUTF16CSVFile() throws {
        let data = try XCTUnwrap("First Name,Last Name,Year Level\nAva,Ng,Year 5".data(using: .utf16))
        let url = try writeTemporaryFile(name: "roster.csv", data: data)

        let parsed = try SpreadsheetImportFile.parseTabularImportFile(url: url, label: "Roster")

        XCTAssertEqual(parsed.rows[0]["First Name"], "Ava")
    }

    func testParseTabularImportFileRejectsEmptyAndOversizedFilesBeforeParsing() throws {
        let emptyURL = try writeTemporaryFile(name: "empty.csv", data: Data())
        XCTAssertThrowsError(try SpreadsheetImportFile.parseTabularImportFile(url: emptyURL, label: "Roster")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .emptyFile)
        }

        let oversizedURL = try writeTemporaryFile(
            name: "oversized.csv",
            data: Data(repeating: UInt8(ascii: "x"), count: SpreadsheetImportFile.maxImportBytes + 1)
        )
        XCTAssertThrowsError(try SpreadsheetImportFile.parseTabularImportFile(url: oversizedURL, label: "Roster")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .fileTooLarge(SpreadsheetImportFile.maxImportBytes / 1024))
        }
    }

    func testImportFormatRejectsUnsupportedSpreadsheetAndDocumentExtensions() throws {
        XCTAssertEqual(
            try SpreadsheetImportFile.importFormat(for: URL(fileURLWithPath: "results.xlsx"), label: "Results"),
            .xlsx
        )
        XCTAssertEqual(
            try SpreadsheetImportFile.importFormat(for: URL(fileURLWithPath: "results.xls"), label: "Results"),
            .xls
        )

        for filename in ["results.xlsm", "results.xlsb", "results.ods", "results.numbers", "results.docx"] {
            XCTAssertThrowsError(try SpreadsheetImportFile.importFormat(for: URL(fileURLWithPath: filename), label: "Results")) { error in
                XCTAssertEqual(error as? SpreadsheetImportFileError, .unsupportedFormat("Results"))
            }
        }
    }

    func testParseXLSXRejectsMalformedZipAsUnreadableWorkbook() {
        XCTAssertThrowsError(try SpreadsheetImportFile.parseXLSX(Data("not-xlsx".utf8), label: "Roster workbook")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .unreadableWorkbook("Roster workbook"))
        }
    }

    func testParseXLSXAcceptsInlineStringWorkbookWithoutSharedStrings() throws {
        let data = try workbookData(sheetXML: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1" t="inlineStr"><is><t>First Name</t></is></c>
              <c r="B1" t="inlineStr"><is><t>Last Name</t></is></c>
              <c r="C1" t="inlineStr"><is><t>Year Level</t></is></c>
            </row>
            <row r="2">
              <c r="A2" t="inlineStr"><is><t>Ava</t></is></c>
              <c r="B2" t="inlineStr"><is><t>Ng</t></is></c>
              <c r="C2" t="inlineStr"><is><t>Year 5</t></is></c>
            </row>
          </sheetData>
        </worksheet>
        """)

        let parsed = try SpreadsheetImportFile.parseXLSX(data, label: "Roster workbook")

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name", "Year Level"])
        XCTAssertEqual(parsed.rows, [["First Name": "Ava", "Last Name": "Ng", "Year Level": "Year 5"]])
    }

    func testParseXLSXAcceptsSharedStringWorkbook() throws {
        let data = try workbookData(
            sheetXML: """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="s"><v>0</v></c>
                  <c r="B1" t="s"><v>1</v></c>
                  <c r="C1" t="s"><v>2</v></c>
                </row>
                <row r="2">
                  <c r="A2" t="s"><v>3</v></c>
                  <c r="B2" t="s"><v>4</v></c>
                  <c r="C2" t="s"><v>5</v></c>
                </row>
              </sheetData>
            </worksheet>
            """,
            sharedStringsXML: """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="6" uniqueCount="6">
              <si><t>First Name</t></si>
              <si><t>Last Name</t></si>
              <si><t>Year Level</t></si>
              <si><t>Ava</t></si>
              <si><t>Ng</t></si>
              <si><t>Year 5</t></si>
            </sst>
            """
        )

        let parsed = try SpreadsheetImportFile.parseXLSX(data, label: "Roster workbook")

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name", "Year Level"])
        XCTAssertEqual(parsed.rows, [["First Name": "Ava", "Last Name": "Ng", "Year Level": "Year 5"]])
    }

    func testParseXLSXAcceptsNumericCells() throws {
        let data = try workbookData(sheetXML: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1" t="inlineStr"><is><t>Student ID</t></is></c>
              <c r="B1" t="inlineStr"><is><t>Score</t></is></c>
            </row>
            <row r="2">
              <c r="A2" t="inlineStr"><is><t>S1</t></is></c>
              <c r="B2"><v>42</v></c>
            </row>
          </sheetData>
        </worksheet>
        """)

        let parsed = try SpreadsheetImportFile.parseXLSX(data, label: "Results workbook")

        XCTAssertEqual(parsed.headers, ["Student ID", "Score"])
        XCTAssertEqual(parsed.rows, [["Student ID": "S1", "Score": "42"]])
    }

    func testParseXLSXRejectsSharedStringCellsWhenSharedStringsPartIsMissing() throws {
        let data = try workbookData(sheetXML: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="A1" t="s"><v>0</v></c>
            </row>
          </sheetData>
        </worksheet>
        """)

        XCTAssertThrowsError(try SpreadsheetImportFile.parseXLSX(data, label: "Roster workbook")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .unreadableWorkbook("Roster workbook"))
        }
    }

    func testParseXLSXRejectsBrokenWorkbookRelationshipsInsteadOfFallbackImportingSheets() throws {
        let data = try workbookData(
            sheetXML: """
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
              <sheetData>
                <row r="1">
                  <c r="A1" t="inlineStr"><is><t>First Name</t></is></c>
                  <c r="B1" t="inlineStr"><is><t>Last Name</t></is></c>
                </row>
                <row r="2">
                  <c r="A2" t="inlineStr"><is><t>Ava</t></is></c>
                  <c r="B2" t="inlineStr"><is><t>Ng</t></is></c>
                </row>
              </sheetData>
            </worksheet>
            """,
            includeWorkbookRelationships: false
        )

        XCTAssertThrowsError(try SpreadsheetImportFile.parseXLSX(data, label: "Roster workbook")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .unreadableWorkbook("Roster workbook"))
        }
    }

    func testParseXLSXRejectsOutOfBoundsColumnReferencesBeforeAllocation() throws {
        let data = try workbookData(sheetXML: """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            <row r="1">
              <c r="BM1" t="inlineStr"><is><t>First Name</t></is></c>
            </row>
            <row r="2">
              <c r="BM2" t="inlineStr"><is><t>Ava</t></is></c>
            </row>
          </sheetData>
        </worksheet>
        """)

        XCTAssertThrowsError(try SpreadsheetImportFile.parseXLSX(data, label: "Roster workbook")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .unreadableWorkbook("Roster workbook"))
        }
    }

    func testBoundedOOXMLExtractionRejectsLargeExpandedEntries() throws {
        let data = try OOXMLZipWriter.archive(entries: [
            OOXMLZipEntry(
                path: "xl/sharedStrings.xml",
                data: Data(repeating: UInt8(ascii: "x"), count: SpreadsheetImportFile.maxWorkbookEntryBytes + 1)
            )
        ])

        XCTAssertThrowsError(try OOXMLZipWriter.storedEntries(
            data,
            maximumEntryBytes: SpreadsheetImportFile.maxWorkbookEntryBytes,
            maximumTotalUncompressedBytes: SpreadsheetImportFile.maxWorkbookUncompressedBytes,
            allowedPaths: { _ in true }
        )) { error in
            XCTAssertEqual(error as? OOXMLZipWriterError, .entryTooLarge("xl/sharedStrings.xml"))
        }
    }

    func testParseXLSRejectsMalformedOLEOrMissingWorkbookStream() throws {
        let url = try writeTemporaryFile(name: "bad.xls", data: Data("not-xls".utf8))

        XCTAssertThrowsError(try SpreadsheetImportFile.parseXLS(url, label: "Roster workbook")) { error in
            XCTAssertEqual(error as? SpreadsheetImportFileError, .unreadableWorkbook("Roster workbook"))
        }
    }

    func testParseXLSReadsGeneratedWorkbookStream() throws {
        let data = try LegacyXLSWorkbookWriter.workbook(
            rows: [
                ["First Name", "Last Name", "Year Level"],
                ["Ava", "Ng", "Year 5"]
            ],
            sheetName: "Roster"
        )
        let url = try writeTemporaryFile(name: "roster.xls", data: data)

        let parsed = try SpreadsheetImportFile.parseTabularImportFile(url: url, label: "Roster")

        XCTAssertEqual(parsed.headers, ["First Name", "Last Name", "Year Level"])
        XCTAssertEqual(parsed.rows, [["First Name": "Ava", "Last Name": "Ng", "Year Level": "Year 5"]])
    }

    private func writeTemporaryFile(name: String, data: Data) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSSpreadsheetImportTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url)
        return url
    }

    private func workbookData(
        sheetXML: String,
        sharedStringsXML: String? = nil,
        includeWorkbookRelationships: Bool = true
    ) throws -> Data {
        var entries = [
            OOXMLZipEntry(path: "[Content_Types].xml", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
              <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
              <Default Extension="xml" ContentType="application/xml"/>
              <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
              <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
              \(includeWorkbookRelationships ? "" : #"<Override PartName="/xl/_rels/workbook.xml.rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>"#)
              \(sharedStringsXML == nil ? "" : #"<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>"#)
            </Types>
            """.utf8)),
            OOXMLZipEntry(path: "_rels/.rels", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
            </Relationships>
            """.utf8)),
            OOXMLZipEntry(path: "xl/workbook.xml", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
              <sheets>
                <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
              </sheets>
            </workbook>
            """.utf8))
        ]
        if includeWorkbookRelationships {
            entries.append(OOXMLZipEntry(path: "xl/_rels/workbook.xml.rels", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
              <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            </Relationships>
            """.utf8)))
        }
        entries.append(OOXMLZipEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8)))
        if let sharedStringsXML {
            entries.append(OOXMLZipEntry(path: "xl/sharedStrings.xml", data: Data(sharedStringsXML.utf8)))
        }
        return try OOXMLZipWriter.archive(entries: entries)
    }
}
