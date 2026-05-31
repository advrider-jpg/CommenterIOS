import CommentEngine
import CommenterDomain
import CommenterImportExport
import Foundation
import XCTest

final class ReviewWorkbookFileTests: XCTestCase {
    func testPrepareReviewWorkbookFileWritesVerifiedXLSXPackage() throws {
        let root = temporaryRoot()
        var project = fixtureProject()
        project.reports = [
            readyReport(
                project: project,
                result: project.results[0],
                text: "Generated text should not be exported.",
                manualEdit: "=Manual edit & final comment.",
                generatedAt: 1,
                variantIds: ["private-variant"],
                trace: "private trace"
            )
        ]

        let prepared = try prepareReviewWorkbookFile(project: project, format: .xlsx, directory: root)
        let entries = try readStoredZipEntries(prepared.url)
        let sheet = try XCTUnwrap(entries["xl/worksheets/sheet1.xml"].flatMap { String(data: $0, encoding: .utf8) })

        XCTAssertEqual(prepared.url.lastPathComponent, "Project_Report_Review.xlsx")
        XCTAssertEqual(prepared.format, .xlsx)
        XCTAssertEqual(prepared.rowCount, 1)
        XCTAssertGreaterThan(prepared.byteCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.url.path))
        XCTAssertEqual(Data(try Data(contentsOf: prepared.url).prefix(2)), Data("PK".utf8))
        XCTAssertNotNil(entries["[Content_Types].xml"])
        XCTAssertNotNil(entries["_rels/.rels"])
        XCTAssertNotNil(entries["xl/workbook.xml"])
        XCTAssertNotNil(entries["xl/_rels/workbook.xml.rels"])
        XCTAssertNotNil(entries["xl/styles.xml"])
        XCTAssertTrue(sheet.contains("Student Name"))
        XCTAssertTrue(sheet.contains("&apos;=Manual edit &amp; final comment."))
        XCTAssertFalse(sheet.contains("private-variant"))
        XCTAssertFalse(sheet.contains("private trace"))
    }

    func testPrepareReviewWorkbookFileWritesVerifiedLegacyXLSWorkbook() throws {
        let root = temporaryRoot()
        var project = fixtureProject()
        project.reports = [
            readyReport(
                project: project,
                result: project.results[0],
                text: "Generated text should not be exported.",
                manualEdit: "+Manual edit final comment.",
                generatedAt: 1,
                variantIds: ["private-variant"],
                trace: "private trace"
            )
        ]

        let prepared = try prepareReviewWorkbookFile(project: project, format: .xls, directory: root)
        let data = try Data(contentsOf: prepared.url)
        let workbookStream = try readCompoundWorkbookStream(data)
        let labels = try readBIFFLabels(workbookStream)

        XCTAssertEqual(prepared.url.lastPathComponent, "Project_Report_Review.xls")
        XCTAssertEqual(prepared.format, .xls)
        XCTAssertEqual(prepared.rowCount, 1)
        XCTAssertGreaterThan(prepared.byteCount, 0)
        XCTAssertTrue(data.starts(with: Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])))
        XCTAssertFalse(data.starts(with: Data("PK".utf8)))
        XCTAssertTrue(labels.contains("Student Name"))
        XCTAssertTrue(labels.contains("'+Manual edit final comment."))
        XCTAssertFalse(labels.contains("Generated text should not be exported."))
        XCTAssertFalse(labels.contains("private-variant"))
        XCTAssertFalse(labels.contains("private trace"))
        XCTAssertTrue(try readBoundSheetNames(workbookStream).contains("Reports"))
    }

    func testPrepareReviewWorkbookFileRejectsUnsupportedFormatsHonestly() throws {
        let root = temporaryRoot()

        XCTAssertThrowsError(try prepareReviewWorkbookFile(project: fixtureProject(), format: .docx, directory: root)) { error in
            XCTAssertEqual(error as? ReviewWorkbookFileError, .unsupportedFormat(.docx))
        }
    }

    func testPrepareReviewWorkbookFileLeavesNoFileWhenReadinessFails() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var project = fixtureProject()
        project.reports = [
            readyReport(project: project, result: project.results[0], text: "Ava is still using [context].")
        ]

        XCTAssertThrowsError(try prepareReviewWorkbookFile(project: project, format: .xlsx, directory: root)) { error in
            XCTAssertTrue(String(describing: error).contains("template text"))
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(files, [])
    }

    func testPrepareReviewWorkbookFileRejectsNonDirectoryDestination() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: fileURL)

        XCTAssertThrowsError(try prepareReviewWorkbookFile(project: fixtureProject(), format: .xlsx, directory: fileURL)) { error in
            guard case .invalidDirectory = error as? ReviewWorkbookFileError else {
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
            .appendingPathComponent("CommenterIOSReviewWorkbookTests-\(UUID().uuidString)", isDirectory: true)
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

    private func readCompoundWorkbookStream(_ data: Data) throws -> Data {
        XCTAssertTrue(data.starts(with: Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])))
        let sectorSize = 512
        let firstDirectorySector = Int(uint32LE(data, 48))
        let directoryOffset = sectorSize + (firstDirectorySector * sectorSize)
        XCTAssertLessThanOrEqual(directoryOffset + sectorSize, data.count)
        let directory = Data(data[directoryOffset..<directoryOffset + sectorSize])
        for offset in stride(from: 0, to: directory.count, by: 128) {
            let entry = Data(directory[offset..<offset + 128])
            if directoryEntryName(entry) == "Workbook" {
                let startSector = Int(uint32LE(entry, 116))
                let streamSize = Int(uint64LE(entry, 120))
                let streamOffset = sectorSize + (startSector * sectorSize)
                XCTAssertLessThanOrEqual(streamOffset + streamSize, data.count)
                return Data(data[streamOffset..<streamOffset + streamSize])
            }
        }
        XCTFail("Missing Workbook stream")
        return Data()
    }

    private func readBIFFLabels(_ stream: Data) throws -> [String] {
        try biffRecords(stream).compactMap { record in
            guard record.id == 0x0204 else { return nil }
            return decodeXLUnicodeString(record.payload, offset: 6)
        }
    }

    private func readBoundSheetNames(_ stream: Data) throws -> [String] {
        try biffRecords(stream).compactMap { record in
            guard record.id == 0x0085, record.payload.count >= 8 else { return nil }
            let sheetOffset = Int(uint32LE(record.payload, 0))
            XCTAssertLessThan(sheetOffset + 4, stream.count)
            XCTAssertEqual(uint16LE(stream, sheetOffset), 0x0809)
            let length = Int(record.payload[6])
            let flags = record.payload[7]
            let start = 8
            if flags & 0x01 == 0 {
                return String(bytes: record.payload[start..<start + length], encoding: .utf8)
            }
            return String(
                decoding: stride(from: start, to: start + (length * 2), by: 2).map { uint16LE(record.payload, $0) },
                as: UTF16.self
            )
        }
    }

    private func biffRecords(_ stream: Data) throws -> [(id: UInt16, payload: Data)] {
        var records: [(id: UInt16, payload: Data)] = []
        var offset = 0
        while offset + 4 <= stream.count {
            let id = uint16LE(stream, offset)
            let length = Int(uint16LE(stream, offset + 2))
            let payloadStart = offset + 4
            let payloadEnd = payloadStart + length
            XCTAssertLessThanOrEqual(payloadEnd, stream.count)
            records.append((id: id, payload: Data(stream[payloadStart..<payloadEnd])))
            offset = payloadEnd
        }
        return records
    }

    private func decodeXLUnicodeString(_ payload: Data, offset: Int) -> String? {
        guard offset + 3 <= payload.count else { return nil }
        let length = Int(uint16LE(payload, offset))
        let flags = payload[offset + 2]
        let start = offset + 3
        if flags & 0x01 == 0 {
            guard start + length <= payload.count else { return nil }
            return String(bytes: payload[start..<start + length], encoding: .utf8)
        }
        guard start + (length * 2) <= payload.count else { return nil }
        return String(
            decoding: stride(from: start, to: start + (length * 2), by: 2).map { uint16LE(payload, $0) },
            as: UTF16.self
        )
    }

    private func directoryEntryName(_ entry: Data) -> String {
        let byteCount = Int(uint16LE(entry, 64))
        guard byteCount >= 2, byteCount <= 64 else { return "" }
        let units = stride(from: 0, to: byteCount - 2, by: 2).map { uint16LE(entry, $0) }
        return String(decoding: units, as: UTF16.self)
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

    private func uint64LE(_ data: Data, _ offset: Int) -> UInt64 {
        UInt64(uint32LE(data, offset)) | (UInt64(uint32LE(data, offset + 4)) << 32)
    }
}
