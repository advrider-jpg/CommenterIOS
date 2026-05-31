import CommenterDomain
@testable import CommenterImportExport
import Foundation
import XCTest

final class ProjectImportCommitTests: XCTestCase {
    func testRosterImportPreparesAppendedProjectWithoutClaimingSave() throws {
        let imported = [
            Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        ]

        let change = try projectByApplyingRosterImport(imported, to: fixtureProject(), nowMilliseconds: 42)

        XCTAssertEqual(change.kind, .roster)
        XCTAssertEqual(change.importedCount, 1)
        XCTAssertEqual(change.project.roster.map(\.id), ["s1", "s2"])
        XCTAssertEqual(change.project.metadata.updatedAt, 42)
        XCTAssertEqual(change.project.results.map(\.studentId), ["s1"])
    }

    func testResultsImportMergesByStudentAndSubject() throws {
        let replacement = AchievementResult(
            studentId: "s1",
            subject: "English",
            achievementLevel: .aboveStandard,
            focusStrand: "Writing"
        )
        let added = AchievementResult(
            studentId: "s1",
            subject: "Mathematics",
            achievementLevel: .developing,
            focusStrand: "Number"
        )
        var project = fixtureProject()
        project.metadata.selectedSubjects["Mathematics"] = SelectedSubject(name: "Mathematics", allStrandsSelected: true)

        let change = try projectByApplyingResultsImport([replacement, added], to: project, nowMilliseconds: 99)

        XCTAssertEqual(change.kind, .results)
        XCTAssertEqual(change.importedCount, 2)
        XCTAssertEqual(change.project.results.count, 2)
        XCTAssertEqual(change.project.results.first { $0.subject == "English" }?.achievementLevel, .aboveStandard)
        XCTAssertEqual(change.project.results.first { $0.subject == "Mathematics" }?.achievementLevel, .developing)
        XCTAssertEqual(change.project.metadata.updatedAt, 99)
    }

    func testInvalidImportsLeaveOriginalProjectValueUnchanged() throws {
        let original = fixtureProject()

        XCTAssertThrowsError(try projectByApplyingRosterImport([
            Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
        ], to: original, nowMilliseconds: 2)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.roster.count, 1)
        XCTAssertEqual(original.metadata.updatedAt, 1)

        XCTAssertThrowsError(try projectByApplyingResultsImport([
            AchievementResult(studentId: "missing", subject: "English", achievementLevel: .atStandard)
        ], to: original, nowMilliseconds: 3)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.results.count, 1)
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    func testEmptyImportsAreExplicitlyRejected() {
        XCTAssertThrowsError(try projectByApplyingRosterImport([], to: fixtureProject(), nowMilliseconds: 1)) { error in
            XCTAssertEqual(error as? ProjectImportCommitError, .emptyRosterImport)
        }
        XCTAssertThrowsError(try projectByApplyingResultsImport([], to: fixtureProject(), nowMilliseconds: 1)) { error in
            XCTAssertEqual(error as? ProjectImportCommitError, .emptyResultsImport)
        }
    }

    func testExistingInvalidProjectIsRejectedBeforeApplyingImport() {
        var invalidProject = fixtureProject()
        invalidProject.results.append(AchievementResult(studentId: "missing", subject: "English", achievementLevel: .atStandard))

        XCTAssertThrowsError(try projectByApplyingRosterImport([
            Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        ], to: invalidProject, nowMilliseconds: 2)) { error in
            XCTAssertTrue(error.localizedDescription.contains("existing project is not valid"))
        }
    }

    func testRosterImportPreviewParsesXLSXAndDoesNotMutateOriginalProject() throws {
        let original = fixtureProject()
        let url = try writeTemporaryFile(
            name: "roster.xlsx",
            data: try workbookData(rows: [
                ["First Name", "Last Name", "Year Level"],
                ["Ben", "Stone", "Year 6"]
            ])
        )

        let preview = try prepareRosterImportPreview(
            from: url,
            project: original,
            nowMilliseconds: 42,
            createID: { "s2" }
        )

        XCTAssertEqual(preview.sourceFormat, .xlsx)
        XCTAssertEqual(preview.acceptedRows, 1)
        XCTAssertEqual(preview.change.kind, .roster)
        XCTAssertEqual(preview.change.project.roster.map(\.id), ["s1", "s2"])
        XCTAssertEqual(preview.change.project.metadata.updatedAt, 42)
        XCTAssertEqual(original.roster.map(\.id), ["s1"])
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    func testResultsImportPreviewParsesNarrowLegacyXLSFixture() throws {
        var original = fixtureProject()
        original.metadata.selectedSubjects["Mathematics"] = SelectedSubject(name: "Mathematics", allStrandsSelected: true)
        let data = try LegacyXLSWorkbookWriter.workbook(
            rows: [
                ["First Name", "Last Name", "Year Level", "Subject", "Achievement Level", "Focus"],
                ["Ava", "Ng", "Year 5", "Mathematics", "Above Standard", "Number"]
            ],
            sheetName: "Results"
        )
        let url = try writeTemporaryFile(name: "results.xls", data: data)

        let preview = try prepareResultsImportPreview(from: url, project: original, nowMilliseconds: 99)

        XCTAssertEqual(preview.sourceFormat, .xls)
        XCTAssertEqual(preview.acceptedRows, 1)
        XCTAssertEqual(preview.change.kind, .results)
        XCTAssertEqual(preview.change.project.results.count, 2)
        XCTAssertEqual(preview.change.project.results.first { $0.subject == "Mathematics" }?.achievementLevel, .aboveStandard)
        XCTAssertEqual(preview.change.project.metadata.updatedAt, 99)
        XCTAssertEqual(original.results.count, 1)
        XCTAssertNil(original.results.first { $0.subject == "Mathematics" })
    }

    func testRosterImportPreviewRejectsNoOpCSVBeforeTeacherConfirmation() throws {
        let original = fixtureProject()
        let url = try writeTemporaryFile(
            name: "roster.csv",
            data: Data("First Name,Last Name,Year Level\n".utf8)
        )

        XCTAssertThrowsError(try prepareRosterImportPreview(
            from: url,
            project: original,
            nowMilliseconds: 42,
            createID: { "s2" }
        )) { error in
            XCTAssertEqual(error as? ImportPreviewPreparationError, .noAcceptedRows("student"))
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.roster.map(\.id), ["s1"])
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    func testResultsImportPreviewRejectsNoOpCSVBeforeTeacherConfirmation() throws {
        let original = fixtureProject()
        let url = try writeTemporaryFile(
            name: "results.csv",
            data: Data("First Name,Last Name,Subject,Achievement Level\n".utf8)
        )

        XCTAssertThrowsError(try prepareResultsImportPreview(
            from: url,
            project: original,
            nowMilliseconds: 99
        )) { error in
            XCTAssertEqual(error as? ImportPreviewPreparationError, .noAcceptedRows("result"))
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.results.count, 1)
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    func testImportPreviewRejectsPartialRowsBeforePreparedProjectIsReturned() throws {
        let original = fixtureProject()
        let url = try writeTemporaryFile(
            name: "roster.csv",
            data: Data("""
            First Name,Last Name,Year Level
            Ben,Stone,Year 6
            Cara,Lee,Year 4
            """.utf8)
        )

        XCTAssertThrowsError(try prepareRosterImportPreview(
            from: url,
            project: original,
            nowMilliseconds: 42,
            createID: { UUID().uuidString }
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Import blocked"))
            XCTAssertTrue(error.localizedDescription.contains("row 3"))
        }
        XCTAssertEqual(original.roster.map(\.id), ["s1"])
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    private func fixtureProject() -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: false
            ),
            roster: [
                Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
            ],
            results: [
                AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)
            ]
        )
    }

    private func writeTemporaryFile(name: String, data: Data) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSProjectImportPreviewTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent(name, isDirectory: false)
        try data.write(to: url)
        return url
    }

    private func workbookData(rows: [[String]]) throws -> Data {
        let sheetRows = rows.enumerated().map { rowIndex, values in
            let rowNumber = rowIndex + 1
            let cells = values.enumerated().map { columnIndex, value in
                let reference = "\(columnName(columnIndex + 1))\(rowNumber)"
                return #"              <c r="\#(reference)" t="inlineStr"><is><t>\#(xmlEscape(value))</t></is></c>"#
            }.joined(separator: "\n")
            return """
                    <row r="\(rowNumber)">
        \(cells)
                    </row>
        """
        }.joined()
        let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
        \(sheetRows)
          </sheetData>
        </worksheet>
        """
        return try OOXMLZipWriter.archive(entries: [
            OOXMLZipEntry(path: "[Content_Types].xml", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>
            """.utf8)),
            OOXMLZipEntry(path: "_rels/.rels", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
            """.utf8)),
            OOXMLZipEntry(path: "xl/workbook.xml", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
            """.utf8)),
            OOXMLZipEntry(path: "xl/_rels/workbook.xml.rels", data: Data("""
            <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
            <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>
            """.utf8)),
            OOXMLZipEntry(path: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8))
        ])
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
}
