import CommenterDomain
@testable import CommenterImportExport
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

    func testEncryptedBackupDetectionAndPasswordRequiredError() throws {
        let encrypted = minimalEncryptedPayload(ciphertext: "ciphertext")

        XCTAssertTrue(looksLikeEncryptedProjectBackup(serialized: encrypted))
        XCTAssertFalse(looksLikeEncryptedProjectBackup(serialized: "{"))

        XCTAssertThrowsError(try parseProjectBackup(serialized: encrypted)) { error in
            XCTAssertEqual(error as? BackupError, .encryptedPasswordRequired)
            XCTAssertEqual(
                (error as? BackupError)?.errorDescription,
                "This is an encrypted project backup. Enter the backup password to import it."
            )
        }
    }

    func testEncryptedBackupRoundTripsThroughV3EnvelopeShape() throws {
        let password = "correct horse battery"
        let encrypted = try serializeEncryptedProjectBackup(
            project: fixtureProject(),
            password: password,
            createdAt: Date(timeIntervalSince1970: 0),
            iterations: 2,
            salt: Data((0..<16).map { UInt8($0) }),
            iv: Data((16..<28).map { UInt8($0) })
        )
        let data = try XCTUnwrap(encrypted.data(using: .utf8))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encryption = try XCTUnwrap(payload["encryption"] as? [String: Any])

        XCTAssertEqual(payload["format"] as? String, encryptedProjectBackupFormat)
        XCTAssertEqual(payload["version"] as? Int, encryptedProjectBackupVersion)
        XCTAssertEqual(encryption["algorithm"] as? String, "AES-GCM")
        XCTAssertEqual(encryption["kdf"] as? String, "PBKDF2-SHA-256")
        XCTAssertEqual(encryption["iterations"] as? Int, 2)
        XCTAssertEqual(encryption["plaintextFormat"] as? String, projectBackupFormat)
        XCTAssertEqual(encryption["plaintextVersion"] as? Int, projectBackupVersion)
        XCTAssertEqual(encryption["aad"] as? String, "backup-envelope-v2")

        let restored = try parseProjectBackup(serialized: encrypted, password: password)
        XCTAssertEqual(restored.metadata.id, "p1")
        XCTAssertEqual(restored.results.first?.textType, "persuasive text")
        XCTAssertEqual(try projectFingerprint(restored), try projectFingerprint(fixtureProject()))
    }

    func testParsesV3WebCryptoEncryptedBackupFixture() throws {
        let restored = try parseProjectBackup(serialized: v3WebCryptoEncryptedFixture(), password: "correct horse battery")

        XCTAssertEqual(restored.metadata.id, "web-v3-project")
        XCTAssertEqual(restored.metadata.name, "Web V3 Project")
        XCTAssertEqual(restored.roster.first?.firstName, "Ava")
        XCTAssertEqual(restored.results.first?.learningContext, "advertising unit")
    }

    func testEncryptedBackupRejectsWrongPasswordAndVerifiedCiphertextTampering() throws {
        let password = "correct horse battery"
        let encrypted = try serializeEncryptedProjectBackup(
            project: fixtureProject(),
            password: password,
            createdAt: Date(timeIntervalSince1970: 0),
            iterations: 2,
            salt: Data((0..<16).map { UInt8($0) }),
            iv: Data((16..<28).map { UInt8($0) })
        )

        XCTAssertThrowsError(try parseProjectBackup(serialized: encrypted, password: "wrong horse battery")) { error in
            XCTAssertEqual(error as? BackupError, .encryptedCouldNotDecrypt)
        }

        let tampered = try encryptedByChangingCiphertext(encrypted)
        XCTAssertThrowsError(try parseProjectBackup(serialized: tampered, password: password)) { error in
            XCTAssertEqual(error as? BackupError, .encryptedCouldNotDecrypt)
        }
    }

    func testEncryptedBackupRejectsCiphertextChecksumMismatchBeforeDecrypting() throws {
        let encrypted = try serializeEncryptedProjectBackup(
            project: fixtureProject(),
            password: "correct horse battery",
            createdAt: Date(timeIntervalSince1970: 0),
            iterations: 2,
            salt: Data((0..<16).map { UInt8($0) }),
            iv: Data((16..<28).map { UInt8($0) })
        )
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encrypted.utf8)) as? [String: Any])
        payload["ciphertext"] = "AAAA"
        let data = try JSONSerialization.data(withJSONObject: payload)

        XCTAssertThrowsError(try parseProjectBackup(serialized: String(decoding: data, as: UTF8.self), password: "correct horse battery")) { error in
            XCTAssertEqual(error as? BackupError, .couldNotVerify)
        }
    }

    func testEncryptedBackupPasswordValidationMatchesV3Policy() {
        XCTAssertEqual(validateBackupPasswordForEncryption("short").ok, false)
        XCTAssertEqual(validateBackupPasswordForEncryption("only spaces     ").ok, true)
        XCTAssertEqual(validateBackupPasswordForEncryption("            ").message, "Use a password that is not only spaces.")
        XCTAssertEqual(validateBackupPasswordForEncryption("correct horse battery", confirmation: "different password").message, "The backup passwords do not match.")
        XCTAssertEqual(validateBackupPasswordForImport("").message, "Enter the backup password.")
        XCTAssertEqual(validateBackupPasswordForImport("bad\u{0007}password").message, "Backup passwords cannot include control characters.")
    }

    func testProjectFingerprintIgnoresPersistenceMetadata() throws {
        let project = fixtureProject()
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

    private func minimalEncryptedPayload(ciphertext: String) -> String {
        """
        {
          "format": "\(encryptedProjectBackupFormat)",
          "version": \(encryptedProjectBackupVersion),
          "createdAt": "1970-01-01T00:00:00.000Z",
          "encryption": {
            "algorithm": "AES-GCM",
            "kdf": "PBKDF2-SHA-256",
            "iterations": 2,
            "salt": "AAECAwQFBgcICQoLDA0ODw==",
            "iv": "EBESExQVFhcYGRob",
            "plaintextFormat": "\(projectBackupFormat)",
            "plaintextVersion": \(projectBackupVersion),
            "aad": "backup-envelope-v2"
          },
          "checksum": {
            "algorithm": "sha256",
            "ciphertextHash": "\(try! sha256Hex(ciphertext))"
          },
          "ciphertext": "\(ciphertext)"
        }
        """
    }

    private func v3WebCryptoEncryptedFixture() -> String {
        let ciphertext = [
            "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"
        ].joined()
        return """
        {
          "format": "commenter-project-backup-encrypted",
          "version": 2,
          "createdAt": "1970-01-01T00:00:00.000Z",
          "encryption": {
            "algorithm": "AES-GCM",
            "kdf": "PBKDF2-SHA-256",
            "iterations": 2,
            "salt": "AAECAwQFBgcICQoLDA0ODw==",
            "iv": "EBESExQVFhcYGRob",
            "plaintextFormat": "commenter-project-backup",
            "plaintextVersion": 2,
            "aad": "backup-envelope-v2"
          },
          "checksum": {
            "algorithm": "sha256",
            "ciphertextHash": "c0ffee84a9182ccb7d2f347cf5c11b07a3c7254e7d9e7276af0570998c2c093b"
          },
          "ciphertext": "\(ciphertext)"
        }
        """
    }

    private func encryptedByChangingCiphertext(_ encrypted: String) throws -> String {
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(encrypted.utf8)) as? [String: Any])
        guard let ciphertext = payload["ciphertext"] as? String,
              var ciphertextData = Data(base64Encoded: ciphertext),
              !ciphertextData.isEmpty
        else {
            throw BackupError.couldNotOpen
        }
        let firstIndex = ciphertextData.startIndex
        ciphertextData[firstIndex] = ciphertextData[firstIndex] ^ UInt8(0xff)
        let changedCiphertext = ciphertextData.base64EncodedString()
        payload["ciphertext"] = changedCiphertext
        var checksum = try XCTUnwrap(payload["checksum"] as? [String: Any])
        checksum["ciphertextHash"] = try sha256Hex(changedCiphertext)
        payload["checksum"] = checksum
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(decoding: data, as: UTF8.self)
    }
}
