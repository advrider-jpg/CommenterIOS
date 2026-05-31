import CommentEngine
import CommenterDomain
import CommenterImportExport
import Foundation
import XCTest

final class ReportDocumentFileTests: XCTestCase {
    func testPrepareReportDocumentFileWritesVerifiedDOCXPackage() throws {
        let root = temporaryRoot()
        var project = fixtureProject()
        project.reports = [
            readyReport(
                project: project,
                result: project.results[0],
                text: "Generated text should not be exported.",
                manualEdit: "Manual edit & final comment.\n\nSecond paragraph.",
                generatedAt: 1,
                variantIds: ["private-variant"],
                trace: "private trace"
            )
        ]

        let prepared = try prepareReportDocumentFile(project: project, format: .docx, directory: root)
        let entries = try readStoredZipEntries(prepared.url)
        let document = try XCTUnwrap(entries["word/document.xml"].flatMap { String(data: $0, encoding: .utf8) })
        let header = try XCTUnwrap(entries["word/header1.xml"].flatMap { String(data: $0, encoding: .utf8) })
        let footer = try XCTUnwrap(entries["word/footer1.xml"].flatMap { String(data: $0, encoding: .utf8) })

        XCTAssertEqual(prepared.url.lastPathComponent, "Project_Reports.docx")
        XCTAssertEqual(prepared.format, .docx)
        XCTAssertEqual(prepared.studentCount, 1)
        XCTAssertGreaterThan(prepared.byteCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.url.path))
        XCTAssertEqual(Data(try Data(contentsOf: prepared.url).prefix(2)), Data("PK".utf8))
        XCTAssertNotNil(entries["[Content_Types].xml"])
        XCTAssertNotNil(entries["_rels/.rels"])
        XCTAssertNotNil(entries["docProps/core.xml"])
        XCTAssertNotNil(entries["docProps/app.xml"])
        XCTAssertNotNil(entries["word/_rels/document.xml.rels"])
        XCTAssertNotNil(entries["word/styles.xml"])
        XCTAssertTrue(document.contains("Project"))
        XCTAssertTrue(document.contains("Ava Ng"))
        XCTAssertTrue(document.contains("English"))
        XCTAssertTrue(document.contains("Achievement: At Standard"))
        XCTAssertTrue(document.contains("Manual edit &amp; final comment."))
        XCTAssertTrue(document.contains("Second paragraph."))
        XCTAssertTrue(document.contains(#"<w:br w:type="page"/>"#))
        XCTAssertTrue(header.contains("Project"))
        XCTAssertTrue(footer.contains("PAGE"))
        XCTAssertFalse(document.contains("Generated text should not be exported."))
        XCTAssertFalse(document.contains("private-variant"))
        XCTAssertFalse(document.contains("private trace"))
    }

    func testPrepareReportDocumentFileFiltersSingleStudent() throws {
        let root = temporaryRoot()
        var project = fixtureProject()
        let secondStudent = Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        let secondResult = AchievementResult(studentId: "s2", subject: "English", achievementLevel: .aboveStandard, focusStrand: "Reading")
        project.roster.append(secondStudent)
        project.results.append(secondResult)
        project.reports = [
            readyReport(project: project, result: project.results[0], text: "Ava paragraph."),
            readyReport(project: project, result: secondResult, text: "Ben paragraph.")
        ]

        let prepared = try prepareReportDocumentFile(project: project, format: .docx, directory: root, studentId: "s2")
        let document = try XCTUnwrap(try readStoredZipEntries(prepared.url)["word/document.xml"].flatMap { String(data: $0, encoding: .utf8) })

        XCTAssertEqual(prepared.url.lastPathComponent, "Project_Ben_Reports.docx")
        XCTAssertEqual(prepared.studentCount, 1)
        XCTAssertTrue(document.contains("Ben Stone"))
        XCTAssertTrue(document.contains("Focus: Reading"))
        XCTAssertTrue(document.contains("Ben paragraph."))
        XCTAssertFalse(document.contains("Ava Ng"))
        XCTAssertFalse(document.contains("Ava paragraph."))
    }

    func testPrepareReportDocumentFileRejectsUnsupportedFormatsHonestly() throws {
        let root = temporaryRoot()

        XCTAssertThrowsError(try prepareReportDocumentFile(project: fixtureProject(), format: .xlsx, directory: root)) { error in
            XCTAssertEqual(error as? ReportDocumentFileError, .unsupportedFormat(.xlsx))
        }
        XCTAssertThrowsError(try prepareReportDocumentFile(project: fixtureProject(), format: .xls, directory: root)) { error in
            XCTAssertEqual(error as? ReportDocumentFileError, .unsupportedFormat(.xls))
        }
    }

    func testPrepareReportDocumentFileLeavesNoFileWhenReadinessFails() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var project = fixtureProject()
        project.reports = [
            readyReport(project: project, result: project.results[0], text: "Ava is still using [context].")
        ]

        XCTAssertThrowsError(try prepareReportDocumentFile(project: project, format: .docx, directory: root)) { error in
            XCTAssertTrue(String(describing: error).contains("template text"))
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(files, [])
    }

    func testPrepareReportDocumentFileRejectsNonDirectoryDestination() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: fileURL)

        XCTAssertThrowsError(try prepareReportDocumentFile(project: fixtureProject(), format: .docx, directory: fileURL)) { error in
            guard case .invalidDirectory = error as? ReportDocumentFileError else {
                return XCTFail("Expected invalidDirectory, got \(error)")
            }
        }
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
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)]
        )
    }

    private func readyReport(
        project: Project,
        result: AchievementResult,
        text: String,
        manualEdit: String? = nil,
        generatedAt: Int64 = 1,
        variantIds: [String] = [],
        trace: String? = nil
    ) -> GeneratedReport {
        guard let student = project.roster.first(where: { $0.id == result.studentId }) else {
            XCTFail("Missing fixture student")
            return GeneratedReport(studentId: result.studentId, subject: result.subject, text: text, generatedAt: generatedAt)
        }
        return GeneratedReport(
            studentId: result.studentId,
            subject: result.subject,
            concreteSubject: result.focusStrand ?? result.subject,
            text: text,
            variantIds: variantIds,
            trace: trace,
            manualEdit: manualEdit,
            generatedAt: generatedAt,
            resultFingerprint: buildGenerationFingerprint(
                projectMetadata: project.metadata,
                student: student,
                result: result,
                concreteSubject: result.focusStrand ?? result.subject
            )
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSReportDocumentTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func readStoredZipEntries(_ url: URL) throws -> [String: Data] {
        let data = try Data(contentsOf: url)
        var entries: [String: Data] = [:]
        var offset = 0
        while offset + 30 <= data.count {
            guard uint32LE(data, offset) == 0x04034b50 else { break }
            let compressedSize = Int(uint32LE(data, offset + 18))
            let nameLength = Int(uint16LE(data, offset + 26))
            let extraLength = Int(uint16LE(data, offset + 28))
            let nameStart = offset + 30
            let nameEnd = nameStart + nameLength
            let dataStart = nameEnd + extraLength
            let dataEnd = dataStart + compressedSize
            guard nameEnd <= data.count, dataEnd <= data.count else {
                XCTFail("Invalid ZIP entry bounds")
                return entries
            }
            let name = String(decoding: data[nameStart..<nameEnd], as: UTF8.self)
            entries[name] = Data(data[dataStart..<dataEnd])
            offset = dataEnd
        }
        return entries
    }

    private func uint16LE(_ data: Data, _ offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private func uint32LE(_ data: Data, _ offset: Int) -> UInt32 {
        UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}
