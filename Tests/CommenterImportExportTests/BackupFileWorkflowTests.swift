import CommenterDomain
@testable import CommenterImportExport
import Foundation
import XCTest

final class BackupFileWorkflowTests: XCTestCase {
    func testPrepareProjectBackupFileWritesNonEmptyVerifiedBackup() throws {
        let root = temporaryRoot()
        let createdAt = Date(timeIntervalSince1970: 0)

        let prepared = try prepareProjectBackupFile(project: fixtureProject(), directory: root, createdAt: createdAt)

        XCTAssertEqual(prepared.url.lastPathComponent, "Project-Term-1-1970-01-01T00-00-00Z.report-writer-backup.json")
        XCTAssertGreaterThan(prepared.byteCount, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: prepared.url.path))
        XCTAssertEqual(prepared.project.metadata.id, "p1")

        let loaded = try loadProjectBackupFile(from: prepared.url)
        XCTAssertEqual(loaded.project.metadata.id, "p1")
        XCTAssertEqual(loaded.byteCount, prepared.byteCount)
    }

    func testPrepareProjectBackupFileRejectsNonDirectoryDestination() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let fileURL = root.appendingPathComponent("not-a-directory")
        try Data("x".utf8).write(to: fileURL)

        XCTAssertThrowsError(try prepareProjectBackupFile(project: fixtureProject(), directory: fileURL)) { error in
            guard case .invalidDirectory = error as? BackupFileWorkflowError else {
                return XCTFail("Expected invalidDirectory, got \(error)")
            }
        }
    }

    func testLoadProjectBackupFileRejectsEmptyAndTamperedFiles() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let empty = root.appendingPathComponent("empty.report-writer-backup.json")
        try Data().write(to: empty)

        XCTAssertThrowsError(try loadProjectBackupFile(from: empty)) { error in
            guard case .emptyWrittenFile = error as? BackupFileWorkflowError else {
                return XCTFail("Expected emptyWrittenFile, got \(error)")
            }
        }

        let prepared = try prepareProjectBackupFile(project: fixtureProject(), directory: root, createdAt: Date(timeIntervalSince1970: 0))
        var raw = try String(contentsOf: prepared.url, encoding: .utf8)
        raw = raw.replacingOccurrences(of: "\"Project Term 1\"", with: "\"Tampered\"")
        try raw.write(to: prepared.url, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try loadProjectBackupFile(from: prepared.url)) { error in
            XCTAssertEqual(error as? BackupError, .couldNotVerify)
        }
    }

    func testPrepareProjectBackupFileRemovesFileWhenReadbackVerificationFails() throws {
        let root = temporaryRoot()
        let createdAt = Date(timeIntervalSince1970: 0)

        XCTAssertThrowsError(
            try prepareProjectBackupFile(
                project: fixtureProject(),
                directory: root,
                createdAt: createdAt,
                verifyReadBack: { _ in throw BackupError.couldNotVerify }
            )
        ) { error in
            guard case .verificationFailed = error as? BackupFileWorkflowError else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(files, [])
    }

    func testPrepareProjectBackupFileRemovesFileWhenReadbackProjectIdDiffers() throws {
        let root = temporaryRoot()
        let createdAt = Date(timeIntervalSince1970: 0)

        XCTAssertThrowsError(
            try prepareProjectBackupFile(
                project: fixtureProject(),
                directory: root,
                createdAt: createdAt,
                verifyReadBack: { _ in fixtureProject(id: "different-project") }
            )
        ) { error in
            guard case .verificationFailed = error as? BackupFileWorkflowError else {
                return XCTFail("Expected verificationFailed, got \(error)")
            }
        }

        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertEqual(files, [])
    }

    func testBackupFilenameSanitizesProjectNames() {
        let name = backupFilename(project: fixtureProject(name: " *** "), createdAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(name, "report-writer-project-1970-01-01T00-00-00Z.report-writer-backup.json")

        let unsafe = backupFilename(project: fixtureProject(name: "Room: 5 / Term?"), createdAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(unsafe, "Room-5-Term-1970-01-01T00-00-00Z.report-writer-backup.json")
    }

    private func fixtureProject(id: String = "p1", name: String = "Project Term 1") -> Project {
        Project(
            metadata: ProjectMetadata(
                id: id,
                name: name,
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: true
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)]
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSBackupTests-\(UUID().uuidString)", isDirectory: true)
    }
}
