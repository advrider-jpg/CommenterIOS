import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import XCTest

final class BackupEnvelopeTests: XCTestCase {
    func testBackupV2IncludesChecksumAndRejectsTampering() throws {
        let serialized = try serializeProjectBackup(project: fixtureProject(), createdAt: Date(timeIntervalSince1970: 0))
        let data = try XCTUnwrap(serialized.data(using: .utf8))
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(payload["format"] as? String, projectBackupFormat)
        XCTAssertEqual(payload["version"] as? Int, projectBackupVersion)
        let checksum = try XCTUnwrap(payload["checksum"] as? [String: Any])
        XCTAssertEqual(checksum["algorithm"] as? String, "sha256")
        XCTAssertNotNil(checksum["projectFingerprint"] as? String)

        var project = try XCTUnwrap(payload["project"] as? [String: Any])
        var metadata = try XCTUnwrap(project["metadata"] as? [String: Any])
        metadata["name"] = "Tampered"
        project["metadata"] = metadata
        payload["project"] = project

        let tampered = try JSONSerialization.data(withJSONObject: payload)
        XCTAssertThrowsError(try parseProjectBackup(serialized: String(decoding: tampered, as: UTF8.self))) { error in
            XCTAssertEqual(error as? BackupError, .couldNotVerify)
        }
    }

    func testBackupParserPreservesV1CompatibilityForValidProject() throws {
        let payload = ProjectBackupPayload(
            format: projectBackupFormat,
            version: 1,
            createdAt: "1970-01-01T00:00:00.000Z",
            checksum: nil,
            project: fixtureProject()
        )
        let data = try JSONEncoder().encode(payload)
        let restored = try parseProjectBackup(serialized: String(decoding: data, as: UTF8.self))

        XCTAssertEqual(restored.metadata.id, "p1")
        XCTAssertEqual(restored.results.first?.textType, "persuasive text")
        XCTAssertEqual(restored.results.first?.learningContext, "advertising unit")
    }

    func testBackupParserRejectsInvalidRawProjectBeforeReconciliation() throws {
        var invalidProject = fixtureProject()
        invalidProject.results.append(
            AchievementResult(
                studentId: "missing-student",
                subject: "English",
                achievementLevel: .atStandard
            )
        )
        let payload = ProjectBackupPayload(
            format: projectBackupFormat,
            version: 1,
            createdAt: "1970-01-01T00:00:00.000Z",
            checksum: nil,
            project: invalidProject
        )
        let data = try JSONEncoder().encode(payload)

        XCTAssertThrowsError(try parseProjectBackup(serialized: String(decoding: data, as: UTF8.self))) { error in
            XCTAssertEqual(error as? BackupError, .couldNotOpen)
        }
    }

    func testProjectFingerprintIgnoresPersistenceMetadata() throws {
        var project = fixtureProject()
        var saved = project
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 4, savedAt: 123, savedBy: "ios", fingerprint: "existing")

        XCTAssertEqual(try stableProjectString(project), try stableProjectString(saved))
        XCTAssertEqual(try projectFingerprint(project), try projectFingerprint(saved))
    }

    private func fixtureProject() -> Project {
        let metadata = ProjectMetadata(
            id: "p1",
            name: "Project",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 1,
            updatedAt: 1,
            selectedSubjects: [
                "English": SelectedSubject(name: "English", strands: [:], allStrandsSelected: true)
            ],
            useFirstNameOnly: true
        )
        let student = Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5)
        let result = AchievementResult(
            studentId: "s1",
            subject: "English",
            achievementLevel: .atStandard,
            focusStrand: "Reading",
            textType: "persuasive text",
            learningContext: "advertising unit"
        )
        return Project(metadata: metadata, roster: [student], results: [result], reports: [])
    }
}
