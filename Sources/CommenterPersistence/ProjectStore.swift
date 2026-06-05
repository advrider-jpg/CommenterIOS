import CommenterDomain
import Foundation

public enum ProjectStoreError: LocalizedError, Equatable {
    case unavailable(String)
    case projectNotFound(String)
    case invalidProject([String])
    case revisionConflict
    case verificationFailed
    case sqlite(String)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(reason):
            return reason
        case let .projectNotFound(id):
            return "Project \(id) could not be found."
        case let .invalidProject(issues):
            return "Project could not be saved: \(issues.joined(separator: " "))"
        case .revisionConflict:
            return "This project was changed elsewhere. Reopen the project before saving more changes."
        case .verificationFailed:
            return "The project was written, but the saved copy could not be verified. Export a backup and reopen the project."
        case let .sqlite(message):
            return "The local project index could not be updated: \(message)"
        }
    }
}

public struct SaveProjectOptions: Equatable, Sendable {
    public var expectedRevision: Int?
    public var actorId: String
    public var verifyReadAfterWrite: Bool
    public var createRecoverySnapshot: Bool
    public var recoveryReason: RecoveryReason

    public init(
        expectedRevision: Int? = nil,
        actorId: String = "local-ios",
        verifyReadAfterWrite: Bool = true,
        createRecoverySnapshot: Bool = false,
        recoveryReason: RecoveryReason = .beforeSave
    ) {
        self.expectedRevision = expectedRevision
        self.actorId = actorId
        self.verifyReadAfterWrite = verifyReadAfterWrite
        self.createRecoverySnapshot = createRecoverySnapshot
        self.recoveryReason = recoveryReason
    }
}

public enum RecoveryReason: String, Codable, Equatable, Sendable {
    case beforeSave = "before-save"
    case beforeDelete = "before-delete"
    case beforeImportReplace = "before-import-replace"
    case manual
}

public struct RecoverySnapshot: Codable, Equatable, Sendable {
    public var key: String
    public var projectId: String
    public var projectName: String
    public var createdAt: Int64
    public var reason: RecoveryReason
    public var project: Project

    public init(key: String, projectId: String, projectName: String, createdAt: Int64, reason: RecoveryReason, project: Project) {
        self.key = key
        self.projectId = projectId
        self.projectName = projectName
        self.createdAt = createdAt
        self.reason = reason
        self.project = project
    }
}

public struct InvalidProjectRecord: Equatable, Sendable {
    public var id: String
    public var reason: String

    public init(id: String, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct ProjectLoadDiagnostics: Equatable, Sendable {
    public var projects: [Project]
    public var invalidProjects: [InvalidProjectRecord]

    public init(projects: [Project], invalidProjects: [InvalidProjectRecord]) {
        self.projects = projects
        self.invalidProjects = invalidProjects
    }
}

public protocol ProjectStore: Sendable {
    func listProjects() async throws -> [Project]
    func loadProject(id: String) async throws -> Project
    func saveProject(_ project: Project, expectedRevision: Int?) async throws -> Project
}

public struct UnavailableProjectStore: ProjectStore {
    public let reason: String

    public init(reason: String = "Durable local project storage has not been implemented yet.") {
        self.reason = reason
    }

    public func listProjects() async throws -> [Project] {
        throw ProjectStoreError.unavailable(reason)
    }

    public func loadProject(id: String) async throws -> Project {
        throw ProjectStoreError.unavailable(reason)
    }

    public func saveProject(_ project: Project, expectedRevision: Int?) async throws -> Project {
        throw ProjectStoreError.unavailable(reason)
    }
}

public struct FileProjectStore: ProjectStore {
    public let rootURL: URL
    public var now: @Sendable () -> Date

    private var projectsURL: URL { rootURL.appendingPathComponent("projects", isDirectory: true) }
    private var indexURL: URL { projectsURL.appendingPathComponent("index.sqlite") }
    private var exportsTempURL: URL { rootURL.appendingPathComponent("exports-temp", isDirectory: true) }
    private var datasetsURL: URL { rootURL.appendingPathComponent("datasets", isDirectory: true) }

    public init(rootURL: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.rootURL = rootURL
        self.now = now
    }

    public static func applicationSupport(fileManager: FileManager = .default) throws -> FileProjectStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return FileProjectStore(rootURL: base)
    }

    public func listProjects() async throws -> [Project] {
        try await listProjectsWithDiagnostics().projects
    }

    public func listProjectsWithDiagnostics() async throws -> ProjectLoadDiagnostics {
        try ensureStorageLayout()
        let projectDirs = try FileManager.default.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var projects: [Project] = []
        var invalidProjects: [InvalidProjectRecord] = []
        try projectDirs.sorted { $0.lastPathComponent < $1.lastPathComponent }.forEach { url in
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true, url.lastPathComponent != "recovery" else { return }
            let projectFile = url.appendingPathComponent("project.json")
            guard FileManager.default.fileExists(atPath: projectFile.path) else { return }
            do {
                projects.append(try readProject(at: projectFile))
            } catch {
                invalidProjects.append(
                    InvalidProjectRecord(
                        id: diagnosticProjectID(at: projectFile, fallbackID: url.lastPathComponent),
                        reason: invalidProjectReason(error)
                    )
                )
            }
        }
        return ProjectLoadDiagnostics(
            projects: projects.sorted { $0.metadata.updatedAt > $1.metadata.updatedAt },
            invalidProjects: invalidProjects
        )
    }

    public func loadProject(id: String) async throws -> Project {
        let url = projectFileURL(projectId: id)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProjectStoreError.projectNotFound(id)
        }
        return try readProject(at: url)
    }

    public func saveProject(_ project: Project, expectedRevision: Int?) async throws -> Project {
        try saveProject(project, options: SaveProjectOptions(expectedRevision: expectedRevision))
    }

    public func saveProject(_ project: Project, options: SaveProjectOptions = SaveProjectOptions()) throws -> Project {
        try ensureStorageLayout()
        let nowMilliseconds = milliseconds(now())
        var normalized = reconcileProjectForPersistence(project, nowMilliseconds: nowMilliseconds)
        try assertValid(normalized)

        let projectDirectory = projectDirectoryURL(projectId: normalized.metadata.id)
        let projectFile = projectDirectory.appendingPathComponent("project.json")
        let existing = try existingValidProject(at: projectFile)
        let existingRevision = existing?.metadata.persistence?.revision ?? 0

        if let expectedRevision = options.expectedRevision, expectedRevision != existingRevision {
            throw ProjectStoreError.revisionConflict
        }

        if options.createRecoverySnapshot, let existing {
            try createRecoverySnapshot(existing, reason: options.recoveryReason)
        }

        var metadata = normalized.metadata
        metadata.persistence = ProjectPersistenceMetadata(
            revision: existingRevision + 1,
            savedAt: nowMilliseconds,
            savedBy: options.actorId,
            fingerprint: nil
        )
        metadata.updatedAt = nowMilliseconds
        normalized.metadata = metadata
        normalized = reconcileProjectForPersistence(normalized, nowMilliseconds: nowMilliseconds)

        let fingerprint = try projectFingerprint(normalized)
        normalized.metadata.persistence?.fingerprint = fingerprint
        normalized = reconcileProjectForPersistence(normalized, nowMilliseconds: nowMilliseconds)
        normalized.metadata.persistence?.fingerprint = fingerprint

        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try writeProjectAtomically(normalized, to: projectFile)
        try SQLiteProjectIndex(indexURL: indexURL).upsert(project: normalized, projectPath: projectFile, usedVariantIds: reportVariantIds(normalized))

        guard options.verifyReadAfterWrite else {
            return normalized
        }

        let saved = try readProject(at: projectFile)
        let readFingerprint = try projectFingerprint(saved)
        guard readFingerprint == fingerprint, readFingerprint == saved.metadata.persistence?.fingerprint else {
            throw ProjectStoreError.verificationFailed
        }
        return saved
    }

    public func deleteProject(id: String) throws {
        try ensureStorageLayout()
        let directory = projectDirectoryURL(projectId: id)
        let projectFile = directory.appendingPathComponent("project.json")
        guard let existing = try existingValidProject(at: projectFile) else {
            throw ProjectStoreError.projectNotFound(id)
        }
        try createRecoverySnapshot(existing, reason: .beforeDelete)
        if FileManager.default.fileExists(atPath: projectFile.path) {
            try FileManager.default.removeItem(at: projectFile)
        }
        guard !FileManager.default.fileExists(atPath: projectFile.path) else {
            throw ProjectStoreError.verificationFailed
        }
        try SQLiteProjectIndex(indexURL: indexURL).deleteProject(id: id)
    }

    public func createRecoverySnapshot(_ project: Project, reason: RecoveryReason) throws {
        try ensureStorageLayout()
        let normalized = reconcileProjectForPersistence(project, nowMilliseconds: project.metadata.updatedAt)
        try assertValid(normalized)
        let recoveryDirectory = recoveryDirectoryURL(projectId: normalized.metadata.id)
        try FileManager.default.createDirectory(at: recoveryDirectory, withIntermediateDirectories: true)

        let createdAt = milliseconds(now())
        let existing = try listRecoverySnapshots(projectId: normalized.metadata.id)
        let recent = existing.contains { $0.reason == reason && createdAt - $0.createdAt < 60_000 }
        if reason == .beforeSave, recent {
            return
        }

        let snapshot = RecoverySnapshot(
            key: "\(normalized.metadata.id)-\(createdAt)-\(UUID().uuidString)",
            projectId: normalized.metadata.id,
            projectName: normalized.metadata.name,
            createdAt: createdAt,
            reason: reason,
            project: normalized
        )
        let snapshotURL = recoveryDirectory.appendingPathComponent("\(snapshot.key).json")
        let data = try jsonEncoder().encode(snapshot)
        try data.write(to: snapshotURL, options: [.atomic])
        do {
            let verified = try readRecoverySnapshot(at: snapshotURL)
            guard verified == snapshot else {
                throw ProjectStoreError.verificationFailed
            }
        } catch {
            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                try? FileManager.default.removeItem(at: snapshotURL)
            }
            throw error
        }
        try pruneRecoverySnapshots(projectId: normalized.metadata.id)
    }

    public func listRecoverySnapshots(projectId: String? = nil) throws -> [RecoverySnapshot] {
        try ensureStorageLayout()
        let projectDirectories: [URL]
        if let projectId {
            projectDirectories = [projectDirectoryURL(projectId: projectId)]
        } else {
            projectDirectories = try FileManager.default.contentsOfDirectory(
                at: projectsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        }

        let snapshots = try projectDirectories.flatMap { directory -> [RecoverySnapshot] in
            let recovery = directory.appendingPathComponent("recovery", isDirectory: true)
            guard FileManager.default.fileExists(atPath: recovery.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(at: recovery, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .map { try readRecoverySnapshot(at: $0) }
        }
        return snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    public func pruneRecoverySnapshots(projectId: String? = nil) throws {
        let snapshots = try listRecoverySnapshots(projectId: projectId)
        let nowMilliseconds = milliseconds(now())
        let grouped = Dictionary(grouping: snapshots, by: \.projectId)
        for (_, entries) in grouped {
            let sorted = entries.sorted { $0.createdAt > $1.createdAt }
            for (index, snapshot) in sorted.enumerated() {
                if index >= 10 || nowMilliseconds - snapshot.createdAt > 2_592_000_000 {
                    let url = recoveryDirectoryURL(projectId: snapshot.projectId).appendingPathComponent("\(snapshot.key).json")
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                }
            }
        }
    }

    private func ensureStorageLayout() throws {
        try FileManager.default.createDirectory(at: projectsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: datasetsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: exportsTempURL, withIntermediateDirectories: true)
        try SQLiteProjectIndex(indexURL: indexURL).initialize()
    }

    private func projectDirectoryURL(projectId: String) -> URL {
        projectsURL.appendingPathComponent(safePathComponent(projectId), isDirectory: true)
    }

    private func projectFileURL(projectId: String) -> URL {
        projectDirectoryURL(projectId: projectId).appendingPathComponent("project.json")
    }

    private func recoveryDirectoryURL(projectId: String) -> URL {
        projectDirectoryURL(projectId: projectId).appendingPathComponent("recovery", isDirectory: true)
    }

    private func readProject(at url: URL) throws -> Project {
        let project = try jsonDecoder().decode(Project.self, from: Data(contentsOf: url))
        try assertValid(project)
        let readFingerprint = try projectFingerprint(project)
        if let stored = project.metadata.persistence?.fingerprint, stored != readFingerprint {
            throw ProjectStoreError.verificationFailed
        }
        return project
    }

    private func existingValidProject(at url: URL) throws -> Project? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try readProject(at: url)
    }

    private func readRecoverySnapshot(at url: URL) throws -> RecoverySnapshot {
        let snapshot = try jsonDecoder().decode(RecoverySnapshot.self, from: Data(contentsOf: url))
        try assertValid(snapshot.project)
        guard snapshot.projectId == snapshot.project.metadata.id,
              snapshot.projectName == snapshot.project.metadata.name
        else {
            throw ProjectStoreError.verificationFailed
        }
        let readFingerprint = try projectFingerprint(snapshot.project)
        if let stored = snapshot.project.metadata.persistence?.fingerprint, stored != readFingerprint {
            throw ProjectStoreError.verificationFailed
        }
        return snapshot
    }

    private func writeProjectAtomically(_ project: Project, to url: URL) throws {
        let data = try jsonEncoder().encode(project)
        try data.write(to: url, options: [.atomic])
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        guard (size?.intValue ?? 0) > 0 else {
            throw ProjectStoreError.verificationFailed
        }
    }

    private func assertValid(_ project: Project) throws {
        let validation = validateStoredProjectShape(project)
        guard validation.ok else {
            throw ProjectStoreError.invalidProject(validation.issues)
        }
    }

    private func diagnosticProjectID(at url: URL, fallbackID: String) -> String {
        guard let data = try? Data(contentsOf: url) else { return fallbackID }
        if let project = try? jsonDecoder().decode(Project.self, from: data) {
            let id = project.metadata.id.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? fallbackID : id
        }
        guard
            let json = try? JSONSerialization.jsonObject(with: data),
            let object = json as? [String: Any],
            let metadata = object["metadata"] as? [String: Any],
            let rawID = metadata["id"] as? String
        else {
            return fallbackID
        }
        let id = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? fallbackID : id
    }

    private func invalidProjectReason(_ error: Error) -> String {
        if let storeError = error as? ProjectStoreError {
            switch storeError {
            case let .invalidProject(issues):
                return issues.first ?? "Stored project shape is invalid."
            case .verificationFailed:
                return "Stored project fingerprint verification failed."
            default:
                return storeError.localizedDescription
            }
        }
        if let decoding = error as? DecodingError {
            return "Project JSON could not be decoded: \(decoding.diagnosticSummary)"
        }
        return "Project record could not be loaded: \(error.localizedDescription)"
    }
}

private extension DecodingError {
    var diagnosticSummary: String {
        switch self {
        case let .dataCorrupted(context):
            return context.debugDescription
        case let .keyNotFound(_, context):
            return context.debugDescription
        case let .typeMismatch(_, context):
            return context.debugDescription
        case let .valueNotFound(_, context):
            return context.debugDescription
        @unknown default:
            return localizedDescription
        }
    }
}

private func safePathComponent(_ id: String) -> String {
    id.map { character in
        character.isLetter || character.isNumber || character == "-" || character == "_" ? character : "-"
    }.reduce(into: "") { $0.append($1) }
}

private func milliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}

private func jsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}

private func jsonDecoder() -> JSONDecoder {
    JSONDecoder()
}
