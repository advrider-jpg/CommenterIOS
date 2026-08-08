import CommenterDomain
import Foundation

public enum ProjectStoreError: LocalizedError, Equatable {
    case unavailable(String)
    case projectNotFound(String)
    case invalidProject([String])
    case revisionConflict
    case verificationFailed
    case unsafeProjectIdentifier(String)
    case pathCollision(String)
    case projectIdentifierMismatch(expected: String, actual: String)
    case unsafeStoredProjectPath
    case invalidProjectRecordNotFound
    case invalidProjectRecordChanged
    case invalidProjectRecordIsNowValid
    case invalidProjectSupportCopyFailed
    case invalidProjectSupportCopyNotOwned
    case invalidProjectSupportCopyDiscardFailed
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
        case let .unsafeProjectIdentifier(id):
            return "Project \(id) cannot be saved because its identifier is not storage-safe."
        case let .pathCollision(id):
            return "Project \(id) cannot be saved because its storage path is already used by another local project."
        case let .projectIdentifierMismatch(expected, actual):
            return "The saved project at \(expected) identifies itself as \(actual). It was not loaded because the record is stored under the wrong identifier."
        case .unsafeStoredProjectPath:
            return "A saved-work path is not a regular app-owned file or folder, so it was not opened or changed."
        case .invalidProjectRecordNotFound:
            return "That damaged saved-work record is no longer available. Refresh the project list and try again."
        case .invalidProjectRecordChanged:
            return "That damaged saved-work record changed after it was listed. Refresh the project list before copying or removing it."
        case .invalidProjectRecordIsNowValid:
            return "That saved work is no longer damaged. Refresh the project list before choosing what to remove."
        case .invalidProjectSupportCopyFailed:
            return "The damaged saved-work support copy could not be written and verified. The original record was left unchanged."
        case .invalidProjectSupportCopyNotOwned:
            return "That file is not an app-owned damaged-record support copy, so it was not removed."
        case .invalidProjectSupportCopyDiscardFailed:
            return "The temporary damaged-record support copy could not be removed. Try again before closing Report Writer."
        case let .sqlite(message):
            return "The local project index could not be updated: \(message)"
        }
    }
}

public struct SaveProjectOptions: Equatable, Sendable {
    public var expectedRevision: Int?
    public var actorId: String
    /// Retained for source compatibility. FileProjectStore always verifies every
    /// save before it reports success, even when this legacy option is false.
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
    public var recordID: String?

    public init(id: String, reason: String, recordID: String? = nil) {
        self.id = id
        self.reason = reason
        self.recordID = recordID
    }
}

public struct InvalidProjectSupportCopy: Equatable, Sendable {
    public var recordID: String
    public var fileURL: URL
    public var warning: String

    public init(recordID: String, fileURL: URL, warning: String) {
        self.recordID = recordID
        self.fileURL = fileURL
        self.warning = warning
    }
}

public struct InvalidProjectRemovalReceipt: Equatable, Sendable {
    public var recordID: String
    public var projectId: String
    public var removedAt: Int64
    public var quarantineIdentifier: String

    public init(recordID: String, projectId: String, removedAt: Int64, quarantineIdentifier: String) {
        self.recordID = recordID
        self.projectId = projectId
        self.removedAt = removedAt
        self.quarantineIdentifier = quarantineIdentifier
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

    public init(reason: String = "Local project storage is unavailable in this app configuration.") {
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
    private var invalidProjectQuarantineURL: URL { rootURL.appendingPathComponent("quarantined-damaged-projects", isDirectory: true) }

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
        try ProjectStoreOperationCoordinator.shared.sync {
            try listProjectsWithDiagnosticsLocked()
        }
    }

    private func listProjectsWithDiagnosticsLocked() throws -> ProjectLoadDiagnostics {
        try ensureStorageLayout()
        let projectDirs = try FileManager.default.contentsOfDirectory(
            at: projectsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var projects: [Project] = []
        var invalidProjects: [InvalidProjectRecord] = []
        for url in projectDirs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            } catch {
                invalidProjects.append(
                    InvalidProjectRecord(
                        id: url.lastPathComponent,
                        reason: "Project storage could not be inspected: \(error.localizedDescription)"
                    )
                )
                continue
            }
            if values.isSymbolicLink == true {
                invalidProjects.append(
                    InvalidProjectRecord(
                        id: url.lastPathComponent,
                        reason: ProjectStoreError.unsafeStoredProjectPath.localizedDescription
                    )
                )
                continue
            }
            guard values.isDirectory == true, url.lastPathComponent != "recovery" else { continue }
            let projectFile = url.appendingPathComponent("project.json")
            guard FileManager.default.fileExists(atPath: projectFile.path) else { continue }
            do {
                projects.append(try readProject(at: projectFile, expectedProjectID: url.lastPathComponent))
            } catch {
                invalidProjects.append(
                    InvalidProjectRecord(
                        id: diagnosticProjectID(at: projectFile, fallbackID: url.lastPathComponent),
                        reason: invalidProjectReason(error),
                        recordID: recoverableInvalidProjectRecordID(
                            at: projectFile,
                            storageIdentifier: url.lastPathComponent
                        )
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
        try ProjectStoreOperationCoordinator.shared.sync {
            guard isStorageSafeProjectIdentifier(id) else {
                throw ProjectStoreError.projectNotFound(id)
            }
            try assertRegularDirectoryIfPresent(projectDirectoryURL(projectId: id))
            let url = projectFileURL(projectId: id)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ProjectStoreError.projectNotFound(id)
            }
            return try readProject(at: url, expectedProjectID: id)
        }
    }

    public func saveProject(_ project: Project, expectedRevision: Int?) async throws -> Project {
        try saveProject(project, options: SaveProjectOptions(expectedRevision: expectedRevision))
    }

    public func saveProject(_ project: Project, options: SaveProjectOptions = SaveProjectOptions()) throws -> Project {
        try ProjectStoreOperationCoordinator.shared.sync {
            try saveProjectLocked(project, options: options)
        }
    }

    private func saveProjectLocked(_ project: Project, options: SaveProjectOptions) throws -> Project {
        try ensureStorageLayout()
        let nowMilliseconds = milliseconds(now())
        var normalized = reconcileProjectForPersistence(project, nowMilliseconds: nowMilliseconds)
        try assertValid(normalized)

        guard isStorageSafeProjectIdentifier(normalized.metadata.id) else {
            throw ProjectStoreError.unsafeProjectIdentifier(normalized.metadata.id)
        }

        let projectDirectory = projectDirectoryURL(projectId: normalized.metadata.id)
        try assertRegularDirectoryIfPresent(projectDirectory)
        let projectFile = projectDirectory.appendingPathComponent("project.json")
        let existing = try existingValidProject(at: projectFile)
        if let existing, existing.metadata.id != normalized.metadata.id {
            throw ProjectStoreError.pathCollision(normalized.metadata.id)
        }
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
        try assertValid(normalized)

        try createProtectedDirectory(at: projectDirectory)
        let previousProjectData = try existing.map { _ in try Data(contentsOf: projectFile) }
        var indexWasUpdated = false
        do {
            try writeProjectAtomically(normalized, to: projectFile)
            let saved = try verifiedProject(at: projectFile, expectedFingerprint: fingerprint)
            try SQLiteProjectIndex(indexURL: indexURL).upsert(
                project: saved,
                projectPath: projectFile,
                usedVariantIds: reportVariantIds(saved)
            )
            indexWasUpdated = true
            try applyFileProtectionToSQLiteStore(at: indexURL)
            return saved
        } catch {
            do {
                try restoreProjectFile(afterFailedSaveAt: projectFile, previousData: previousProjectData)
                if indexWasUpdated {
                    if let existing {
                        try SQLiteProjectIndex(indexURL: indexURL).upsert(
                            project: existing,
                            projectPath: projectFile,
                            usedVariantIds: reportVariantIds(existing)
                        )
                    } else {
                        try SQLiteProjectIndex(indexURL: indexURL).deleteProject(id: normalized.metadata.id)
                    }
                    try applyFileProtectionToSQLiteStore(at: indexURL)
                }
            } catch {
                throw ProjectStoreError.verificationFailed
            }
            throw error
        }
    }

    public func deleteProject(id: String) throws {
        try ProjectStoreOperationCoordinator.shared.sync {
            try deleteProjectLocked(id: id)
        }
    }

    private func deleteProjectLocked(id: String) throws {
        try ensureStorageLayout()
        guard isStorageSafeProjectIdentifier(id) else {
            throw ProjectStoreError.projectNotFound(id)
        }
        let directory = projectDirectoryURL(projectId: id)
        try assertRegularDirectoryIfPresent(directory)
        let projectFile = directory.appendingPathComponent("project.json")
        guard let existing = try existingValidProject(at: projectFile, expectedProjectID: id) else {
            throw ProjectStoreError.projectNotFound(id)
        }
        try createRecoverySnapshot(existing, reason: .beforeDelete)
        let stagedFile = directory.appendingPathComponent(".project-delete-\(UUID().uuidString).json")
        try FileManager.default.moveItem(at: projectFile, to: stagedFile)
        do {
            try SQLiteProjectIndex(indexURL: indexURL).deleteProject(id: id)
            try applyFileProtectionToSQLiteStore(at: indexURL)
        } catch {
            do {
                try restoreStagedProjectFile(from: stagedFile, to: projectFile)
            } catch {
                throw ProjectStoreError.verificationFailed
            }
            throw error
        }
        do {
            try FileManager.default.removeItem(at: stagedFile)
        } catch {
            do {
                try restoreStagedProjectFile(from: stagedFile, to: projectFile)
                try SQLiteProjectIndex(indexURL: indexURL).upsert(
                    project: existing,
                    projectPath: projectFile,
                    usedVariantIds: reportVariantIds(existing)
                )
                try applyFileProtectionToSQLiteStore(at: indexURL)
            } catch {
                throw ProjectStoreError.verificationFailed
            }
            throw error
        }
    }

    /// Creates an exact-byte diagnostic copy of a damaged record. The returned
    /// file is deliberately labelled as non-restorable and is not a backup.
    public func prepareInvalidProjectSupportCopy(recordID: String) throws -> InvalidProjectSupportCopy {
        try ProjectStoreOperationCoordinator.shared.sync {
            try ensureStorageLayout()
            let resolved = try resolveInvalidProjectRecord(recordID: recordID)
            let filename = "Damaged-\(resolved.storageIdentifier)-Support-Copy-NOT-A-BACKUP-\(milliseconds(now()))-\(UUID().uuidString).json"
            let destination = exportsTempURL.appendingPathComponent(filename, isDirectory: false)
            do {
                try resolved.data.write(to: destination, options: [.atomic])
                try applyFileProtection(to: destination)
                let copiedData = try Data(contentsOf: destination)
                let currentSourceData = try Data(contentsOf: resolved.projectFile)
                guard copiedData == resolved.data,
                      currentSourceData == resolved.data
                else {
                    throw ProjectStoreError.invalidProjectRecordChanged
                }
                return InvalidProjectSupportCopy(
                    recordID: recordID,
                    fileURL: destination,
                    warning: "This is a raw damaged-record support copy, not a backup. It cannot be restored or imported as a Commenter backup."
                )
            } catch let error as ProjectStoreError {
                do {
                    try removeTemporaryFileIfPresent(at: destination)
                } catch {
                    throw ProjectStoreError.invalidProjectSupportCopyFailed
                }
                throw error
            } catch {
                do {
                    try removeTemporaryFileIfPresent(at: destination)
                } catch {
                    throw ProjectStoreError.invalidProjectSupportCopyFailed
                }
                throw ProjectStoreError.invalidProjectSupportCopyFailed
            }
        }
    }

    /// Removes only an exact support-copy file owned by this store. Missing
    /// files are already in the requested end state; unrelated paths, nested
    /// paths, directories, and symbolic links are rejected.
    public func discardInvalidProjectSupportCopy(at fileURL: URL) throws {
        try ProjectStoreOperationCoordinator.shared.sync {
            try discardInvalidProjectSupportCopyLocked(at: fileURL)
        }
    }

    /// Purges app-owned raw damaged-record copies older than twelve hours.
    /// Inspection or removal failures are surfaced so launch cleanup cannot
    /// silently claim success while private raw bytes remain on disk.
    public func purgeStaleInvalidProjectSupportCopies() throws {
        try ProjectStoreOperationCoordinator.shared.sync {
            guard FileManager.default.fileExists(atPath: exportsTempURL.path) else { return }
            try assertRegularDirectoryIfPresent(exportsTempURL)
            let files = try FileManager.default.contentsOfDirectory(
                at: exportsTempURL,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            let cutoff = now().addingTimeInterval(-(12 * 60 * 60))
            for fileURL in files where isOwnedInvalidProjectSupportCopy(fileURL) {
                let values = try fileURL.resourceValues(
                    forKeys: [.contentModificationDateKey, .isRegularFileKey, .isSymbolicLinkKey]
                )
                guard values.isRegularFile == true, values.isSymbolicLink != true else {
                    throw ProjectStoreError.unsafeStoredProjectPath
                }
                let modifiedAt = values.contentModificationDate ?? .distantPast
                if modifiedAt < cutoff {
                    try discardInvalidProjectSupportCopyLocked(at: fileURL)
                }
            }
        }
    }

    /// Removes a damaged record from active project storage by moving its whole
    /// directory into an app-owned quarantine. Recovery files are preserved.
    public func removeInvalidProject(recordID: String) throws -> InvalidProjectRemovalReceipt {
        try ProjectStoreOperationCoordinator.shared.sync {
            try ensureStorageLayout()
            let resolved = try resolveInvalidProjectRecord(recordID: recordID)
            try createProtectedDirectory(at: invalidProjectQuarantineURL)
            let removedAt = milliseconds(now())
            let quarantineIdentifier = "\(resolved.storageIdentifier)-\(removedAt)-\(UUID().uuidString)"
            let quarantineURL = invalidProjectQuarantineURL.appendingPathComponent(quarantineIdentifier, isDirectory: true)

            try FileManager.default.moveItem(at: resolved.projectDirectory, to: quarantineURL)
            let quarantinedProjectFile = quarantineURL.appendingPathComponent("project.json", isDirectory: false)
            do {
                let quarantinedData = try Data(contentsOf: quarantinedProjectFile)
                let quarantinedHash = try sha256Hex(quarantinedData)
                guard quarantinedHash == resolved.contentHash else {
                    throw ProjectStoreError.invalidProjectRecordChanged
                }
                try applyFileProtection(to: quarantineURL)
                try applyFileProtection(to: quarantinedProjectFile)
                try SQLiteProjectIndex(indexURL: indexURL).deleteProject(atProjectPath: resolved.projectFile) {
                    try applyFileProtectionToSQLiteStore(at: indexURL)
                }
            } catch {
                do {
                    guard !FileManager.default.fileExists(atPath: resolved.projectDirectory.path) else {
                        throw ProjectStoreError.verificationFailed
                    }
                    try FileManager.default.moveItem(at: quarantineURL, to: resolved.projectDirectory)
                } catch {
                    throw ProjectStoreError.verificationFailed
                }
                throw error
            }

            return InvalidProjectRemovalReceipt(
                recordID: recordID,
                projectId: resolved.diagnosticProjectID,
                removedAt: removedAt,
                quarantineIdentifier: quarantineIdentifier
            )
        }
    }

    public func createRecoverySnapshot(_ project: Project, reason: RecoveryReason) throws {
        try ProjectStoreOperationCoordinator.shared.sync {
            try createRecoverySnapshotLocked(project, reason: reason)
        }
    }

    private func createRecoverySnapshotLocked(_ project: Project, reason: RecoveryReason) throws {
        try ensureStorageLayout()
        // A recovery point must preserve the exact last verified project. Running
        // persistence reconciliation here could filter rows or derive metadata,
        // leaving the snapshot different from the work it claims to recover.
        try assertValid(project)
        guard isStorageSafeProjectIdentifier(project.metadata.id) else {
            throw ProjectStoreError.unsafeProjectIdentifier(project.metadata.id)
        }
        let recoveryDirectory = recoveryDirectoryURL(projectId: project.metadata.id)
        try assertRegularDirectoryIfPresent(projectDirectoryURL(projectId: project.metadata.id))
        try createProtectedDirectory(at: recoveryDirectory)

        let createdAt = milliseconds(now())
        let existing = try listRecoverySnapshotsLocked(projectId: project.metadata.id)
        let recent = existing.contains {
            let age = elapsedMilliseconds(from: $0.createdAt, to: createdAt)
            return $0.reason == reason && age >= 0 && age < 60_000
        }
        if reason == .beforeSave, recent {
            return
        }

        let snapshot = RecoverySnapshot(
            key: "\(project.metadata.id)-\(createdAt)-\(UUID().uuidString)",
            projectId: project.metadata.id,
            projectName: project.metadata.name,
            createdAt: createdAt,
            reason: reason,
            project: project
        )
        let snapshotURL = recoveryDirectory.appendingPathComponent("\(snapshot.key).json")
        let data = try jsonEncoder().encode(snapshot)
        do {
            try data.write(to: snapshotURL, options: [.atomic])
            try applyFileProtection(to: snapshotURL)
            let verified = try readRecoverySnapshot(
                at: snapshotURL,
                expectedProjectID: project.metadata.id
            )
            guard verified == snapshot else {
                throw ProjectStoreError.verificationFailed
            }
        } catch {
            do {
                try removeTemporaryFileIfPresent(at: snapshotURL)
            } catch {
                throw ProjectStoreError.verificationFailed
            }
            throw error
        }
        try pruneRecoverySnapshotsLocked(projectId: project.metadata.id)
    }

    public func listRecoverySnapshots(projectId: String? = nil) throws -> [RecoverySnapshot] {
        try ProjectStoreOperationCoordinator.shared.sync {
            try listRecoverySnapshotsLocked(projectId: projectId)
        }
    }

    private func listRecoverySnapshotsLocked(projectId: String? = nil) throws -> [RecoverySnapshot] {
        try ensureStorageLayout()
        let projectDirectories: [URL]
        if let projectId {
            guard isStorageSafeProjectIdentifier(projectId) else { return [] }
            let directory = projectDirectoryURL(projectId: projectId)
            try assertRegularDirectoryIfPresent(directory)
            projectDirectories = [directory]
        } else {
            let entries = try FileManager.default.contentsOfDirectory(
                at: projectsURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles]
            )
            projectDirectories = try entries.filter { entry in
                let values = try entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                if values.isSymbolicLink == true {
                    throw ProjectStoreError.unsafeStoredProjectPath
                }
                return values.isDirectory == true
            }
        }

        let snapshots = try projectDirectories.flatMap { directory -> [RecoverySnapshot] in
            let recovery = directory.appendingPathComponent("recovery", isDirectory: true)
            guard FileManager.default.fileExists(atPath: recovery.path) else { return [] }
            try assertRegularDirectoryIfPresent(recovery)
            return try FileManager.default.contentsOfDirectory(at: recovery, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .map { try readRecoverySnapshot(at: $0, expectedProjectID: directory.lastPathComponent) }
        }
        return snapshots.sorted { $0.createdAt > $1.createdAt }
    }

    public func pruneRecoverySnapshots(projectId: String? = nil) throws {
        try ProjectStoreOperationCoordinator.shared.sync {
            try pruneRecoverySnapshotsLocked(projectId: projectId)
        }
    }

    private func pruneRecoverySnapshotsLocked(projectId: String? = nil) throws {
        let snapshots = try listRecoverySnapshotsLocked(projectId: projectId)
        let nowMilliseconds = milliseconds(now())
        let grouped = Dictionary(grouping: snapshots, by: \.projectId)
        for (_, entries) in grouped {
            let sorted = entries.sorted { $0.createdAt > $1.createdAt }
            for (index, snapshot) in sorted.enumerated() {
                if index >= 10 || elapsedMilliseconds(from: snapshot.createdAt, to: nowMilliseconds) > 2_592_000_000 {
                    let url = recoveryDirectoryURL(projectId: snapshot.projectId).appendingPathComponent("\(snapshot.key).json")
                    if FileManager.default.fileExists(atPath: url.path) {
                        try FileManager.default.removeItem(at: url)
                    }
                }
            }
        }
    }

    private func ensureStorageLayout() throws {
        try createProtectedDirectory(at: rootURL)
        try createProtectedDirectory(at: projectsURL)
        try createProtectedDirectory(at: datasetsURL)
        try createProtectedDirectory(at: exportsTempURL)
        try SQLiteProjectIndex(indexURL: indexURL).initialize()
        try applyFileProtectionToSQLiteStore(at: indexURL)
    }

    private func projectDirectoryURL(projectId: String) -> URL {
        projectsURL.appendingPathComponent(projectId, isDirectory: true)
    }

    private func projectFileURL(projectId: String) -> URL {
        projectDirectoryURL(projectId: projectId).appendingPathComponent("project.json")
    }

    private func recoveryDirectoryURL(projectId: String) -> URL {
        projectDirectoryURL(projectId: projectId).appendingPathComponent("recovery", isDirectory: true)
    }

    private func invalidProjectRecordID(storageIdentifier: String, projectData: Data) throws -> String {
        guard isStorageSafeProjectIdentifier(storageIdentifier) else {
            throw ProjectStoreError.invalidProjectRecordNotFound
        }
        return "invalid-project:\(storageIdentifier):\(try sha256Hex(projectData))"
    }

    private func recoverableInvalidProjectRecordID(at projectFile: URL, storageIdentifier: String) -> String? {
        guard let values = try? projectFile.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let data = try? Data(contentsOf: projectFile)
        else {
            return nil
        }
        return try? invalidProjectRecordID(
            storageIdentifier: storageIdentifier,
            projectData: data
        )
    }

    private func resolveInvalidProjectRecord(recordID: String) throws -> ResolvedInvalidProjectRecord {
        let components = recordID.split(separator: ":", omittingEmptySubsequences: false)
        guard components.count == 3,
              components[0] == "invalid-project"
        else {
            throw ProjectStoreError.invalidProjectRecordNotFound
        }
        let storageIdentifier = String(components[1])
        let expectedHash = String(components[2])
        guard isStorageSafeProjectIdentifier(storageIdentifier),
              expectedHash.count == 64,
              expectedHash == expectedHash.lowercased(),
              expectedHash.unicodeScalars.allSatisfy({ scalar in
                  (48...57).contains(scalar.value) || (97...102).contains(scalar.value)
              })
        else {
            throw ProjectStoreError.invalidProjectRecordNotFound
        }

        let projectDirectory = projectDirectoryURL(projectId: storageIdentifier)
        guard projectDirectory.deletingLastPathComponent().standardizedFileURL == projectsURL.standardizedFileURL,
              let directoryValues = try? projectDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true
        else {
            throw ProjectStoreError.invalidProjectRecordNotFound
        }
        let projectFile = projectDirectory.appendingPathComponent("project.json", isDirectory: false)
        guard let fileValues = try? projectFile.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
              fileValues.isRegularFile == true,
              fileValues.isSymbolicLink != true,
              let data = try? Data(contentsOf: projectFile)
        else {
            throw ProjectStoreError.invalidProjectRecordNotFound
        }
        let actualHash = try sha256Hex(data)
        guard actualHash == expectedHash else {
            throw ProjectStoreError.invalidProjectRecordChanged
        }

        let isNowValid: Bool
        do {
            _ = try readProject(at: projectFile, expectedProjectID: storageIdentifier)
            isNowValid = true
        } catch {
            isNowValid = false
        }
        guard !isNowValid else {
            throw ProjectStoreError.invalidProjectRecordIsNowValid
        }

        return ResolvedInvalidProjectRecord(
            storageIdentifier: storageIdentifier,
            diagnosticProjectID: diagnosticProjectID(at: projectFile, fallbackID: storageIdentifier),
            projectDirectory: projectDirectory,
            projectFile: projectFile,
            data: data,
            contentHash: actualHash
        )
    }

    private func verifiedProject(at url: URL, expectedFingerprint: String) throws -> Project {
        let saved = try readProject(at: url)
        let readFingerprint = try projectFingerprint(saved)
        guard readFingerprint == expectedFingerprint,
              readFingerprint == saved.metadata.persistence?.fingerprint
        else {
            throw ProjectStoreError.verificationFailed
        }
        return saved
    }

    private func readProject(at url: URL, expectedProjectID: String? = nil) throws -> Project {
        try assertRegularStoredFile(url)
        let project = try jsonDecoder().decode(Project.self, from: Data(contentsOf: url))
        try assertValid(project)
        if let expectedProjectID, project.metadata.id != expectedProjectID {
            throw ProjectStoreError.projectIdentifierMismatch(
                expected: expectedProjectID,
                actual: project.metadata.id
            )
        }
        let readFingerprint = try projectFingerprint(project)
        if let stored = project.metadata.persistence?.fingerprint, stored != readFingerprint {
            throw ProjectStoreError.verificationFailed
        }
        return project
    }

    private func existingValidProject(at url: URL, expectedProjectID: String? = nil) throws -> Project? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try readProject(at: url, expectedProjectID: expectedProjectID)
    }

    private func readRecoverySnapshot(at url: URL, expectedProjectID: String? = nil) throws -> RecoverySnapshot {
        try assertRegularStoredFile(url)
        let snapshot = try jsonDecoder().decode(RecoverySnapshot.self, from: Data(contentsOf: url))
        try assertValid(snapshot.project)
        guard snapshot.projectId == snapshot.project.metadata.id,
              snapshot.projectName == snapshot.project.metadata.name,
              expectedProjectID == nil || snapshot.projectId == expectedProjectID,
              snapshot.createdAt >= 0,
              !snapshot.key.isEmpty,
              url.deletingPathExtension().lastPathComponent == snapshot.key
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
        try applyFileProtection(to: url)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = attributes[.size] as? NSNumber
        guard (size?.intValue ?? 0) > 0 else {
            throw ProjectStoreError.verificationFailed
        }
    }

    private func restoreProjectFile(afterFailedSaveAt url: URL, previousData: Data?) throws {
        if let previousData {
            try previousData.write(to: url, options: [.atomic])
            try applyFileProtection(to: url)
            guard try Data(contentsOf: url) == previousData else {
                throw ProjectStoreError.verificationFailed
            }
        } else {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw ProjectStoreError.verificationFailed
            }
        }
    }

    private func restoreStagedProjectFile(from stagedURL: URL, to projectURL: URL) throws {
        guard FileManager.default.fileExists(atPath: stagedURL.path),
              !FileManager.default.fileExists(atPath: projectURL.path)
        else {
            throw ProjectStoreError.verificationFailed
        }
        try FileManager.default.moveItem(at: stagedURL, to: projectURL)
        try applyFileProtection(to: projectURL)
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw ProjectStoreError.verificationFailed
        }
    }

    private func removeTemporaryFileIfPresent(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        guard !FileManager.default.fileExists(atPath: url.path) else {
            throw ProjectStoreError.verificationFailed
        }
    }

    private func discardInvalidProjectSupportCopyLocked(at fileURL: URL) throws {
        guard isOwnedInvalidProjectSupportCopy(fileURL) else {
            throw ProjectStoreError.invalidProjectSupportCopyNotOwned
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try assertRegularDirectoryIfPresent(exportsTempURL)
        let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ProjectStoreError.invalidProjectSupportCopyNotOwned
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw ProjectStoreError.invalidProjectSupportCopyDiscardFailed
        }
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ProjectStoreError.invalidProjectSupportCopyDiscardFailed
        }
    }

    private func isOwnedInvalidProjectSupportCopy(_ fileURL: URL) -> Bool {
        let standardizedFile = fileURL.standardizedFileURL
        let standardizedDirectory = exportsTempURL.standardizedFileURL
        let filename = standardizedFile.lastPathComponent
        return standardizedFile.deletingLastPathComponent().path == standardizedDirectory.path &&
            filename.hasPrefix("Damaged-") &&
            filename.contains("-Support-Copy-NOT-A-BACKUP-") &&
            standardizedFile.pathExtension.lowercased() == "json"
    }

    private func assertRegularDirectoryIfPresent(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw ProjectStoreError.unsafeStoredProjectPath
        }
    }

    private func assertRegularStoredFile(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ProjectStoreError.unsafeStoredProjectPath
        }
    }

    private func createProtectedDirectory(at url: URL) throws {
        try assertRegularDirectoryIfPresent(url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try applyFileProtection(to: url)
    }

    private func applyFileProtection(to url: URL) throws {
        #if os(iOS)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #else
        _ = url
        #endif
    }

    private func applyFileProtectionToSQLiteStore(at url: URL) throws {
        try applyFileProtection(to: url)
        try applyFileProtection(to: URL(fileURLWithPath: "\(url.path)-wal"))
        try applyFileProtection(to: URL(fileURLWithPath: "\(url.path)-shm"))
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

private struct ResolvedInvalidProjectRecord {
    var storageIdentifier: String
    var diagnosticProjectID: String
    var projectDirectory: URL
    var projectFile: URL
    var data: Data
    var contentHash: String
}

private final class ProjectStoreOperationCoordinator: @unchecked Sendable {
    static let shared = ProjectStoreOperationCoordinator()

    private let lock = NSRecursiveLock()

    private init() {}

    func sync<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
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


private func isStorageSafeProjectIdentifier(_ id: String) -> Bool {
    guard !id.isEmpty, id.count <= 120 else { return false }
    return id.unicodeScalars.allSatisfy { scalar in
        (65...90).contains(scalar.value)
            || (97...122).contains(scalar.value)
            || (48...57).contains(scalar.value)
            || scalar.value == 45
            || scalar.value == 95
    }
}

private func milliseconds(_ date: Date) -> Int64 {
    let value = (date.timeIntervalSince1970 * 1000).rounded()
    guard value.isFinite else { return value.sign == .minus ? Int64.min : Int64.max }
    if value <= Double(Int64.min) { return Int64.min }
    if value >= Double(Int64.max) { return Int64.max }
    return Int64(value)
}

private func elapsedMilliseconds(from earlier: Int64, to later: Int64) -> Int64 {
    let (difference, overflow) = later.subtractingReportingOverflow(earlier)
    guard !overflow else { return later >= earlier ? Int64.max : Int64.min }
    return difference
}

private func jsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}

private func jsonDecoder() -> JSONDecoder {
    JSONDecoder()
}
