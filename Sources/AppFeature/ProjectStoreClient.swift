import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import ComposableArchitecture
import Foundation

public struct ProjectSummary: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var term: String
    public var updatedAt: Int64
    public var revision: Int?

    public init(id: String, name: String, term: String, updatedAt: Int64, revision: Int?) {
        self.id = id
        self.name = name
        self.term = term
        self.updatedAt = updatedAt
        self.revision = revision
    }
}

public struct ProjectListDiagnostics: Equatable, Sendable {
    public var projects: [ProjectSummary]
    public var invalidProjects: [InvalidProjectRecord]

    public init(projects: [ProjectSummary], invalidProjects: [InvalidProjectRecord] = []) {
        self.projects = projects
        self.invalidProjects = invalidProjects
    }
}

public struct ProjectStoreClient: Sendable {
    public var listProjects: @Sendable () async throws -> [ProjectSummary]
    public var listProjectDiagnostics: @Sendable () async throws -> ProjectListDiagnostics
    public var createProject: @Sendable (_ draft: AppFeature.ProjectCreationDraft) async throws -> ProjectSummary
    public var loadProject: @Sendable (_ id: String) async throws -> Project
    public var saveProject: @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project
    public var deleteProject: @Sendable (_ id: String) async throws -> [ProjectSummary]
    public var importRosterFile: @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview
    public var importResultsFile: @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview
    public var importBackup: @Sendable (_ url: URL, _ password: String?) async throws -> Project
    public var prepareBackup: @Sendable (_ project: Project) async throws -> URL
    public var prepareReportExport: @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL
    public var discardPreparedFile: @Sendable (_ url: URL) async throws -> Void
    public var purgeStalePreparedFiles: @Sendable () async -> Void

    public init(
        listProjects: @escaping @Sendable () async throws -> [ProjectSummary],
        listProjectDiagnostics: (@Sendable () async throws -> ProjectListDiagnostics)? = nil,
        createProject: @escaping @Sendable (_ draft: AppFeature.ProjectCreationDraft) async throws -> ProjectSummary,
        loadProject: @escaping @Sendable (_ id: String) async throws -> Project,
        saveProject: @escaping @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project,
        deleteProject: @escaping @Sendable (_ id: String) async throws -> [ProjectSummary],
        importRosterFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview,
        importResultsFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview,
        importBackup: @escaping @Sendable (_ url: URL, _ password: String?) async throws -> Project,
        prepareBackup: @escaping @Sendable (_ project: Project) async throws -> URL,
        prepareReportExport: @escaping @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL,
        discardPreparedFile: @escaping @Sendable (_ url: URL) async throws -> Void = { _ in },
        purgeStalePreparedFiles: @escaping @Sendable () async -> Void = {}
    ) {
        self.listProjects = listProjects
        self.listProjectDiagnostics = listProjectDiagnostics ?? {
            ProjectListDiagnostics(projects: try await listProjects())
        }
        self.createProject = createProject
        self.loadProject = loadProject
        self.saveProject = saveProject
        self.deleteProject = deleteProject
        self.importRosterFile = importRosterFile
        self.importResultsFile = importResultsFile
        self.importBackup = importBackup
        self.prepareBackup = prepareBackup
        self.prepareReportExport = prepareReportExport
        self.discardPreparedFile = discardPreparedFile
        self.purgeStalePreparedFiles = purgeStalePreparedFiles
    }
}

extension ProjectStoreClient: DependencyKey {
    public static let liveValue = ProjectStoreClient(
        listProjects: {
            let store = try FileProjectStore.applicationSupport()
            return try await store.listProjects().map(projectSummary).sorted { $0.updatedAt > $1.updatedAt }
        },
        listProjectDiagnostics: {
            let store = try FileProjectStore.applicationSupport()
            let diagnostics = try await store.listProjectsWithDiagnostics()
            return ProjectListDiagnostics(
                projects: diagnostics.projects.map(projectSummary).sorted { $0.updatedAt > $1.updatedAt },
                invalidProjects: diagnostics.invalidProjects
            )
        },
        createProject: { draft in
            let store = try FileProjectStore.applicationSupport()
            let now = milliseconds(Date())
            let project = Project(
                metadata: ProjectMetadata(
                    id: UUID().uuidString,
                    name: draft.normalizedName,
                    term: draft.normalizedTerm,
                    yearLevel: draft.yearLevel,
                    createdAt: now,
                    updatedAt: now,
                    selectedSubjects: Dictionary(uniqueKeysWithValues: teacherSubjectKeysInCurriculumOrder().map { ($0, SelectedSubject(name: $0, allStrandsSelected: true)) }),
                    useFirstNameOnly: draft.useFirstNameOnly
                )
            )
            let saved = try await store.saveProject(project, expectedRevision: nil)
            return projectSummary(saved)
        },
        loadProject: { id in
            let store = try FileProjectStore.applicationSupport()
            return try await store.loadProject(id: id)
        },
        saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
            let store = try FileProjectStore.applicationSupport()
            return try store.saveProject(
                project,
                options: SaveProjectOptions(
                    expectedRevision: expectedRevision,
                    actorId: "local-ios",
                    verifyReadAfterWrite: true,
                    createRecoverySnapshot: createRecoverySnapshot,
                    recoveryReason: recoveryReason
                )
            )
        },
        deleteProject: { id in
            let store = try FileProjectStore.applicationSupport()
            try store.deleteProject(id: id)
            return try await store.listProjects().map(projectSummary).sorted { $0.updatedAt > $1.updatedAt }
        },
        importRosterFile: { url, project in
            try withSecurityScopedAccess(to: url) {
                try prepareRosterImportPreview(
                    from: url,
                    project: project,
                    nowMilliseconds: milliseconds(Date()),
                    createID: { UUID().uuidString }
                )
            }
        },
        importResultsFile: { url, project in
            try withSecurityScopedAccess(to: url) {
                try prepareResultsImportPreview(
                    from: url,
                    project: project,
                    nowMilliseconds: milliseconds(Date())
                )
            }
        },
        importBackup: { url, password in
            try withSecurityScopedAccess(to: url) {
                try loadProjectBackupFile(from: url, password: password).project
            }
        },
        prepareBackup: { project in
            let directory = try prepareProtectedTemporaryExportDirectory()
            let prepared = try prepareProjectBackupFile(project: project, directory: directory).url
            try? applyTemporaryFileProtection(to: prepared)
            return prepared
        },
        prepareReportExport: { project, format in
            let directory = try prepareProtectedTemporaryExportDirectory()
            let prepared: URL
            switch format {
            case .docx:
                prepared = try prepareReportDocumentFile(project: project, format: format, directory: directory).url
            case .xlsx, .xls:
                prepared = try prepareReviewWorkbookFile(project: project, format: format, directory: directory).url
            case .csv, .backupJSON:
                throw ReportExportPreparationError.unsupportedFormat(format)
            }
            try? applyTemporaryFileProtection(to: prepared)
            return prepared
        },
        discardPreparedFile: { url in
            try discardOwnedTemporaryExport(url)
        },
        purgeStalePreparedFiles: {
            purgeOldTemporaryExports(olderThanSeconds: 60 * 60 * 12)
        }
    )

    public static let testValue = ProjectStoreClient(
        listProjects: {
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        listProjectDiagnostics: nil,
        createProject: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        loadProject: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        saveProject: { _, _, _, _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        deleteProject: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        importRosterFile: { _, _ in
            throw ImportExportError.unavailable(format: .csv, reason: "Project store test dependency was not provided.")
        },
        importResultsFile: { _, _ in
            throw ImportExportError.unavailable(format: .csv, reason: "Project store test dependency was not provided.")
        },
        importBackup: { _, _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        prepareBackup: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        prepareReportExport: { _, format in
            throw ImportExportError.unavailable(format: format, reason: "Project store test dependency was not provided.")
        },
        discardPreparedFile: { _ in },
        purgeStalePreparedFiles: {}
    )
}

public extension DependencyValues {
    var projectStoreClient: ProjectStoreClient {
        get { self[ProjectStoreClient.self] }
        set { self[ProjectStoreClient.self] = newValue }
    }
}

private func temporaryExportDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("ReportWriterExports", isDirectory: true)
}

private func prepareProtectedTemporaryExportDirectory() throws -> URL {
    let directory = temporaryExportDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? applyTemporaryFileProtection(to: directory)
    return directory
}

private func isOwnedTemporaryExport(_ url: URL) -> Bool {
    let directoryPath = temporaryExportDirectory().standardizedFileURL.path
    let candidatePath = url.standardizedFileURL.path
    return candidatePath == directoryPath || candidatePath.hasPrefix(directoryPath + "/")
}

private func discardOwnedTemporaryExport(_ url: URL) throws {
    guard isOwnedTemporaryExport(url) else { return }
    if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
    }
    guard !FileManager.default.fileExists(atPath: url.path) else {
        throw CocoaError(.fileWriteUnknown)
    }
}

private func purgeOldTemporaryExports(olderThanSeconds: TimeInterval) {
    let directory = temporaryExportDirectory()
    guard let urls = try? FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return }

    let cutoff = Date().addingTimeInterval(-olderThanSeconds)
    for url in urls {
        guard isOwnedTemporaryExport(url) else { continue }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        if modified < cutoff {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

private func applyTemporaryFileProtection(to url: URL) throws {
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

private func milliseconds(_ date: Date) -> Int64 {
    Int64((date.timeIntervalSince1970 * 1000).rounded())
}

private func withSecurityScopedAccess<T>(to url: URL, _ operation: () throws -> T) rethrows -> T {
    let isScoped = url.startAccessingSecurityScopedResource()
    defer {
        if isScoped {
            url.stopAccessingSecurityScopedResource()
        }
    }
    return try operation()
}
