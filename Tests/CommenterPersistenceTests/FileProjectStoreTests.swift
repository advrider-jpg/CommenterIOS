import CommenterDomain
import CommenterPersistence
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
        var tick = 1.0
        let store = FileProjectStore(rootURL: root, now: {
            defer { tick += 120 }
            return Date(timeIntervalSince1970: tick)
        })

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
        do {
            _ = try await store.loadProject(id: "p1")
            XCTFail("Expected deleted project to be unavailable after index-backed delete")
        } catch ProjectStoreError.projectNotFound(let id) {
            XCTAssertEqual(id, "p1")
            XCTAssertTrue(FileManager.default.fileExists(atPath: indexURL.path))
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
        let url = root
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(projectId, isDirectory: true)
            .appendingPathComponent("project.json")
        return try fileSize(url)
    }

    private func fileSize(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
