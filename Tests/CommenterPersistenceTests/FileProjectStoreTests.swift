import CommenterDomain
import CommenterPersistence
import Foundation
import XCTest

final class FileProjectStoreTests: XCTestCase {
    func testSaveLoadAndRevisionConflictUseVerifiedLocalFiles() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let saved = try store.saveProject(fixtureProject(), options: SaveProjectOptions(actorId: "test-ios"))

        XCTAssertEqual(saved.metadata.persistence?.revision, 1)
        XCTAssertEqual(saved.metadata.persistence?.savedBy, "test-ios")
        XCTAssertNotNil(saved.metadata.persistence?.fingerprint)
        XCTAssertGreaterThan(try projectJSONSize(root: root, projectId: "p1"), 0)

        let loaded = try await store.loadProject(id: "p1")
        XCTAssertEqual(loaded.metadata.persistence?.fingerprint, saved.metadata.persistence?.fingerprint)
        let listedProjects = try await store.listProjects()
        XCTAssertEqual(listedProjects.map(\.metadata.id), ["p1"])

        do {
            _ = try store.saveProject(loaded, options: SaveProjectOptions(expectedRevision: 0))
            XCTFail("Expected revision conflict")
        } catch ProjectStoreError.revisionConflict {
            XCTAssertTrue(true)
        }
    }

    func testSaveCreatesRecoverySnapshotBeforeVerifiedOverwrite() async throws {
        let root = temporaryRoot()
        let clock = TestClock(start: 1)
        let store = FileProjectStore(rootURL: root, now: { clock.next() })

        let first = try store.saveProject(fixtureProject(), options: SaveProjectOptions(actorId: "test-ios"))
        var changed = first
        changed.metadata.name = "Updated"
        let second = try store.saveProject(changed, options: SaveProjectOptions(expectedRevision: 1, actorId: "test-ios", createRecoverySnapshot: true))

        XCTAssertEqual(second.metadata.persistence?.revision, 2)
        let snapshots = try store.listRecoverySnapshots(projectId: "p1")
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].reason, .beforeSave)
        XCTAssertEqual(snapshots[0].project.metadata.name, "Project")
    }

    func testManualRecoverySnapshotPreservesExactProjectWithoutReconciliation() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        var project = fixtureProject()
        project.metadata.yearLevel = .year6

        try store.createRecoverySnapshot(project, reason: .manual)

        let snapshot = try XCTUnwrap(store.listRecoverySnapshots(projectId: "p1").first)
        XCTAssertEqual(snapshot.project, project)
        XCTAssertEqual(snapshot.project.metadata.yearLevel, .year6)
    }

    func testConcurrentExpectedRevisionSavesCannotBothSucceed() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let first = try store.saveProject(fixtureProject())
        var left = first
        left.metadata.name = "Left"
        var right = first
        right.metadata.name = "Right"

        let outcomes = await withTaskGroup(of: String.self, returning: [String].self) { group in
            [left, right].forEach { candidate in
                group.addTask {
                    do {
                        _ = try store.saveProject(candidate, options: SaveProjectOptions(expectedRevision: 1))
                        return "saved"
                    } catch ProjectStoreError.revisionConflict {
                        return "conflict"
                    } catch {
                        return "unexpected: \(error.localizedDescription)"
                    }
                }
            }
            var results: [String] = []
            for await outcome in group {
                results.append(outcome)
            }
            return results.sorted()
        }

        XCTAssertEqual(outcomes, ["conflict", "saved"])
        let loaded = try await store.loadProject(id: "p1")
        XCTAssertEqual(loaded.metadata.persistence?.revision, 2)
        XCTAssertTrue(["Left", "Right"].contains(loaded.metadata.name))
    }

    func testSaveMaintainsLocalSQLiteIndexFile() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let saved = try store.saveProject(fixtureProject())
        let indexURL = projectIndexURL(root: root)

        XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
        XCTAssertGreaterThan(try fileSize(indexURL), 0)

        var renamed = saved
        renamed.metadata.name = "Renamed Project"
        _ = try store.saveProject(renamed, options: SaveProjectOptions(expectedRevision: 1))
        XCTAssertGreaterThan(try fileSize(indexURL), 0)

        try store.deleteProject(id: "p1")
        let snapshots = try store.listRecoverySnapshots(projectId: "p1")
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].reason, .beforeDelete)
        XCTAssertFalse(snapshots[0].key.isEmpty)
        XCTAssertEqual(snapshots[0].projectId, "p1")
        XCTAssertEqual(snapshots[0].projectName, "Renamed Project")
        XCTAssertEqual(snapshots[0].project.metadata.name, "Renamed Project")
        XCTAssertEqual(snapshots[0].project.metadata.persistence?.revision, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: recoveryDirectoryURL(root: root, projectId: "p1").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "p1").path))
        let allRecoverySnapshots = try store.listRecoverySnapshots()
        XCTAssertEqual(allRecoverySnapshots.map(\.key), snapshots.map(\.key))

        do {
            _ = try await store.loadProject(id: "p1")
            XCTFail("Expected deleted project to be unavailable after index-backed delete")
        } catch ProjectStoreError.projectNotFound(let id) {
            XCTAssertEqual(id, "p1")
            XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
        }
    }

    func testStorageLayoutReportsIndexInitializationFailure() throws {
        let root = temporaryRoot()
        let projectsURL = root.appendingPathComponent("projects", isDirectory: true)
        let indexURL = projectsURL.appendingPathComponent("index.sqlite", isDirectory: true)
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: true)
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })

        do {
            _ = try store.saveProject(fixtureProject())
            XCTFail("Expected index initialization failure to block verified save")
        } catch ProjectStoreError.sqlite(let message) {
            XCTAssertFalse(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "p1").path))
        }
    }

    func testSaveFailsWhenSQLiteIndexCannotBeUpdated() throws {
        try testStorageLayoutReportsIndexInitializationFailure()
    }

    func testDeleteReportsSQLiteIndexCleanupFailure() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject())
        let indexURL = projectIndexURL(root: root)
        try FileManager.default.removeItem(at: indexURL)
        try FileManager.default.createDirectory(at: indexURL, withIntermediateDirectories: false)

        do {
            try store.deleteProject(id: "p1")
            XCTFail("Expected index cleanup failure to block delete success")
        } catch ProjectStoreError.sqlite(let message) {
            XCTAssertFalse(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "p1").path))
        }
    }

    func testRecoverySnapshotListingRejectsMismatchedSnapshotMetadata() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let saved = try store.saveProject(fixtureProject())
        let recoveryDirectory = recoveryDirectoryURL(root: root, projectId: "p1")
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)
        let snapshot = RecoverySnapshot(
            key: "bad-metadata",
            projectId: "other-project",
            projectName: saved.metadata.name,
            createdAt: 1_000,
            reason: .beforeDelete,
            project: saved
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let snapshotURL = recoveryDirectory.appendingPathComponent("bad-metadata.json")
        try encoder.encode(snapshot).write(to: snapshotURL, options: [.atomic])

        do {
            _ = try store.listRecoverySnapshots(projectId: "p1")
            XCTFail("Expected mismatched recovery metadata to fail verification")
        } catch ProjectStoreError.verificationFailed {
            XCTAssertTrue(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "p1").path))
        }
    }

    func testRecoverySnapshotListingRejectsSnapshotStoredUnderAnotherProjectPath() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let saved = try store.saveProject(fixtureProject())
        let wrongDirectory = recoveryDirectoryURL(root: root, projectId: "other-storage")
        try FileManager.default.createDirectory(at: wrongDirectory, withIntermediateDirectories: true)
        let snapshot = RecoverySnapshot(
            key: "wrong-storage",
            projectId: "p1",
            projectName: saved.metadata.name,
            createdAt: 1_000,
            reason: .beforeDelete,
            project: saved
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(
            to: wrongDirectory.appendingPathComponent("wrong-storage.json"),
            options: [.atomic]
        )

        XCTAssertThrowsError(try store.listRecoverySnapshots()) { error in
            XCTAssertEqual(error as? ProjectStoreError, .verificationFailed)
        }
    }

    func testDeleteMissingProjectFailsInsteadOfReportingSnapshotSuccess() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject())
        try FileManager.default.removeItem(at: projectFileURL(root: root, projectId: "p1"))

        do {
            try store.deleteProject(id: "p1")
            XCTFail("Expected missing project delete to fail before reporting recovery snapshot success")
        } catch ProjectStoreError.projectNotFound(let id) {
            XCTAssertEqual(id, "p1")
            XCTAssertTrue(try store.listRecoverySnapshots(projectId: "p1").isEmpty)
        }
    }

    func testSaveRejectsProjectIDsThatAreNotStorageSafe() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject(id: "p-1", name: "Existing"))

        do {
            _ = try store.saveProject(fixtureProject(id: "p/1", name: "Unsafe"))
            XCTFail("Expected unsafe project identifiers to be rejected before filesystem mapping")
        } catch ProjectStoreError.unsafeProjectIdentifier(let id) {
            XCTAssertEqual(id, "p/1")
            let loaded = try await store.loadProject(id: "p-1")
            XCTAssertEqual(loaded.metadata.name, "Existing")
        }
    }

    func testTamperedProjectFailsReadVerification() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject())
        let url = root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent("p1", isDirectory: true)
            .appendingPathComponent("project.json")
        var raw = try String(contentsOf: url)
        raw = raw.replacingOccurrences(of: "\"Project\"", with: "\"Tampered\"")
        try raw.write(to: url, atomically: true, encoding: .utf8)

        do {
            _ = try store.saveProject(fixtureProject(), options: SaveProjectOptions(expectedRevision: 1))
            XCTFail("Expected verification failure while reading existing tampered project")
        } catch ProjectStoreError.verificationFailed {
            XCTAssertTrue(true)
        }
    }

    func testListProjectsPreservesValidProjectsAndReportsInvalidRecords() async throws {
        let root = temporaryRoot()
        let clock = TestClock(start: 1)
        let store = FileProjectStore(rootURL: root, now: { clock.next() })
        _ = try store.saveProject(fixtureProject(id: "valid", name: "Valid Project"))
        _ = try store.saveProject(fixtureProject(id: "tampered", name: "Tampered Project"))
        let tamperedURL = projectFileURL(root: root, projectId: "tampered")
        var raw = try String(contentsOf: tamperedURL)
        raw = raw.replacingOccurrences(of: "\"Tampered Project\"", with: "\"Changed Outside Store\"")
        try raw.write(to: tamperedURL, atomically: true, encoding: .utf8)

        let listedProjects = try await store.listProjects()
        XCTAssertEqual(listedProjects.map(\.metadata.id), ["valid"])

        let diagnostics = try await store.listProjectsWithDiagnostics()
        XCTAssertEqual(diagnostics.projects.map(\.metadata.id), ["valid"])
        XCTAssertEqual(diagnostics.invalidProjects.count, 1)
        XCTAssertEqual(diagnostics.invalidProjects[0].id, "tampered")
        XCTAssertEqual(diagnostics.invalidProjects[0].reason, "Stored project fingerprint verification failed.")
        XCTAssertTrue(diagnostics.invalidProjects[0].recordID?.hasPrefix("invalid-project:tampered:") == true)
    }

    func testDamagedRecordSupportCopyPreservesExactBytesAndLabelsItNonRestorable() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        let damagedData = Data("{not valid project json}".utf8)
        try writeDamagedProject(data: damagedData, storageIdentifier: "damaged", root: root)

        let diagnostics = try await store.listProjectsWithDiagnostics()
        let invalid = try XCTUnwrap(diagnostics.invalidProjects.first)
        let recordID = try XCTUnwrap(invalid.recordID)
        let copy = try store.prepareInvalidProjectSupportCopy(recordID: recordID)

        XCTAssertEqual(try Data(contentsOf: copy.fileURL), damagedData)
        XCTAssertTrue(copy.fileURL.lastPathComponent.contains("NOT-A-BACKUP"))
        XCTAssertTrue(copy.warning.localizedCaseInsensitiveContains("not a backup"))
        XCTAssertTrue(copy.warning.localizedCaseInsensitiveContains("cannot be restored"))
        XCTAssertEqual(try Data(contentsOf: projectFileURL(root: root, projectId: "damaged")), damagedData)
    }

    func testDiscardDamagedRecordSupportCopyRemovesOnlyTheExactOwnedFile() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 100_000) })
        try writeDamagedProject(data: Data("broken".utf8), storageIdentifier: "damaged", root: root)
        let diagnostics = try await store.listProjectsWithDiagnostics()
        let recordID = try XCTUnwrap(diagnostics.invalidProjects.first?.recordID)
        let copy = try store.prepareInvalidProjectSupportCopy(recordID: recordID)
        let unrelated = root.appendingPathComponent("unrelated.json")
        try Data("keep".utf8).write(to: unrelated, options: [.atomic])

        try store.discardInvalidProjectSupportCopy(at: copy.fileURL)

        XCTAssertFalse(FileManager.default.fileExists(atPath: copy.fileURL.path))
        XCTAssertThrowsError(try store.discardInvalidProjectSupportCopy(at: unrelated)) { error in
            XCTAssertEqual(error as? ProjectStoreError, .invalidProjectSupportCopyNotOwned)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
    }

    func testPurgeRemovesOnlyStaleOwnedDamagedRecordSupportCopies() async throws {
        let root = temporaryRoot()
        let now = Date(timeIntervalSince1970: 100_000)
        let store = FileProjectStore(rootURL: root, now: { now })
        try writeDamagedProject(data: Data("broken".utf8), storageIdentifier: "damaged", root: root)
        let diagnostics = try await store.listProjectsWithDiagnostics()
        let recordID = try XCTUnwrap(diagnostics.invalidProjects.first?.recordID)
        let stale = try store.prepareInvalidProjectSupportCopy(recordID: recordID)
        let fresh = try store.prepareInvalidProjectSupportCopy(recordID: recordID)
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-(12 * 60 * 60) - 1)],
            ofItemAtPath: stale.fileURL.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-1)],
            ofItemAtPath: fresh.fileURL.path
        )

        try store.purgeStaleInvalidProjectSupportCopies()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.fileURL.path))
    }

    func testPurgeSurfacesUnsafeMatchingEntryInsteadOfClaimingCleanup() throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 100_000) })
        let matchingDirectory = root
            .appendingPathComponent("exports-temp", isDirectory: true)
            .appendingPathComponent("Damaged-record-Support-Copy-NOT-A-BACKUP-old.json", isDirectory: true)
        try FileManager.default.createDirectory(at: matchingDirectory, withIntermediateDirectories: true)

        XCTAssertThrowsError(try store.purgeStaleInvalidProjectSupportCopies()) { error in
            XCTAssertEqual(error as? ProjectStoreError, .unsafeStoredProjectPath)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: matchingDirectory.path))
    }

    func testDamagedRecordTokenRejectsChangedBytesWithoutCopyingOrRemovingRecord() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        try writeDamagedProject(data: Data("broken-one".utf8), storageIdentifier: "damaged", root: root)
        let diagnostics = try await store.listProjectsWithDiagnostics()
        let recordID = try XCTUnwrap(diagnostics.invalidProjects.first?.recordID)
        try Data("broken-two".utf8).write(
            to: projectFileURL(root: root, projectId: "damaged"),
            options: [.atomic]
        )

        XCTAssertThrowsError(try store.prepareInvalidProjectSupportCopy(recordID: recordID)) { error in
            XCTAssertEqual(error as? ProjectStoreError, .invalidProjectRecordChanged)
        }
        XCTAssertThrowsError(try store.removeInvalidProject(recordID: recordID)) { error in
            XCTAssertEqual(error as? ProjectStoreError, .invalidProjectRecordChanged)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "damaged").path))
    }

    func testRemoveDamagedRecordQuarantinesWholeDirectoryAndPreservesValidLogicalIDCollision() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject(id: "collision", name: "Valid Collision"))

        let damagedData = Data(#"{"metadata":{"id":"collision"},"unreadable":true}"#.utf8)
        try writeDamagedProject(data: damagedData, storageIdentifier: "damaged-slot", root: root)
        let recoveryURL = recoveryDirectoryURL(root: root, projectId: "damaged-slot")
        try FileManager.default.createDirectory(at: recoveryURL, withIntermediateDirectories: true)
        let recoveryData = Data("preserve recovery evidence".utf8)
        try recoveryData.write(to: recoveryURL.appendingPathComponent("raw-recovery.json"), options: [.atomic])

        let diagnostics = try await store.listProjectsWithDiagnostics()
        let invalid = try XCTUnwrap(diagnostics.invalidProjects.first { $0.id == "collision" })
        let recordID = try XCTUnwrap(invalid.recordID)
        let receipt = try store.removeInvalidProject(recordID: recordID)

        XCTAssertEqual(receipt.projectId, "collision")
        XCTAssertEqual(receipt.recordID, recordID)
        XCTAssertFalse(FileManager.default.fileExists(atPath: projectFileURL(root: root, projectId: "damaged-slot").path))
        let quarantineURL = root
            .appendingPathComponent("quarantined-damaged-projects", isDirectory: true)
            .appendingPathComponent(receipt.quarantineIdentifier, isDirectory: true)
        XCTAssertEqual(try Data(contentsOf: quarantineURL.appendingPathComponent("project.json")), damagedData)
        XCTAssertEqual(
            try Data(contentsOf: quarantineURL.appendingPathComponent("recovery/raw-recovery.json")),
            recoveryData
        )

        let valid = try await store.loadProject(id: "collision")
        XCTAssertEqual(valid.metadata.name, "Valid Collision")
        let afterRemoval = try await store.listProjectsWithDiagnostics()
        XCTAssertTrue(afterRemoval.invalidProjects.isEmpty)
    }

    func testLoadRejectsProjectStoredUnderDifferentDirectoryIdentifier() async throws {
        let root = temporaryRoot()
        let store = FileProjectStore(rootURL: root, now: { Date(timeIntervalSince1970: 1) })
        _ = try store.saveProject(fixtureProject(id: "actual"))
        let actualData = try Data(contentsOf: projectFileURL(root: root, projectId: "actual"))
        try writeDamagedProject(data: actualData, storageIdentifier: "claimed", root: root)

        do {
            _ = try await store.loadProject(id: "claimed")
            XCTFail("Expected a path and project identifier mismatch to be rejected")
        } catch ProjectStoreError.projectIdentifierMismatch(let expected, let actual) {
            XCTAssertEqual(expected, "claimed")
            XCTAssertEqual(actual, "actual")
        }
    }

    func testStableFingerprintJSONEscapesStringsWithoutSilentFallback() {
        XCTAssertEqual(
            stableJSONString(.string("line\n\"quote\"\\slash\u{0001}")),
            #""line\n\"quote\"\\slash\u0001""#
        )
        XCTAssertEqual(
            stableJSONString(.number(Double.greatestFiniteMagnitude)),
            String(Double.greatestFiniteMagnitude)
        )
        XCTAssertEqual(stableJSONString(.number(.nan)), "null")
    }

    func testStableFingerprintNumbersMatchJavaScriptJSONFormattingThresholds() {
        XCTAssertEqual(stableJSONString(.number(-0.0)), "0")
        XCTAssertEqual(stableJSONString(.number(1e20)), "100000000000000000000")
        XCTAssertEqual(stableJSONString(.number(1e21)), "1e+21")
        XCTAssertEqual(stableJSONString(.number(1e-6)), "0.000001")
        XCTAssertEqual(stableJSONString(.number(1e-7)), "1e-7")
        XCTAssertEqual(stableJSONString(.number(Double(Int64.max))), "9223372036854776000")
    }

    func testStableFingerprintObjectKeysUseJavaScriptUTF16Ordering() {
        let supplementary = "\u{1F600}"
        let privateUseBMP = "\u{E000}"
        let decomposed = "e\u{301}"
        let object: JSONValue = .object([
            privateUseBMP: .number(3),
            supplementary: .number(2),
            decomposed: .number(1),
            "f": .number(4)
        ])

        XCTAssertEqual(
            stableJSONString(object),
            "{\"\(decomposed)\":1,\"f\":4,\"\(supplementary)\":2,\"\(privateUseBMP)\":3}"
        )
    }

    private func fixtureProject(id: String = "p1", name: String = "Project") -> Project {
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
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)],
            reports: [
                GeneratedReport(
                    studentId: "s1",
                    subject: "English",
                    text: "Ava writes clearly in English.",
                    variantIds: ["v1", "v2"],
                    isLocked: false,
                    generatedAt: 1,
                    resultFingerprint: "result-fingerprint"
                )
            ]
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CommenterIOSTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func projectIndexURL(root: URL) -> URL {
        root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent("index.sqlite")
    }

    private func projectJSONSize(root: URL, projectId: String) throws -> UInt64 {
        try fileSize(projectFileURL(root: root, projectId: projectId))
    }

    private func projectFileURL(root: URL, projectId: String) -> URL {
        root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId, isDirectory: true)
            .appendingPathComponent("project.json")
    }

    private func recoveryDirectoryURL(root: URL, projectId: String) -> URL {
        let url = root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId, isDirectory: true)
            .appendingPathComponent("recovery", isDirectory: true)
        return url
    }

    private func writeDamagedProject(data: Data, storageIdentifier: String, root: URL) throws {
        let projectURL = projectFileURL(root: root, projectId: storageIdentifier)
        try FileManager.default.createDirectory(
            at: projectURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: projectURL, options: [.atomic])
    }

    private func fileSize(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var tick: TimeInterval

    init(start: TimeInterval) {
        self.tick = start
    }

    func next() -> Date {
        lock.lock()
        defer { lock.unlock() }
        let date = Date(timeIntervalSince1970: tick)
        tick += 120
        return date
    }
}
