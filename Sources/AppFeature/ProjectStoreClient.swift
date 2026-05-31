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

public struct ProjectStoreClient: Sendable {
    public var listProjects: @Sendable () async throws -> [ProjectSummary]
    public var createProject: @Sendable () async throws -> ProjectSummary
    public var loadProject: @Sendable (_ id: String) async throws -> Project
    public var saveProject: @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project
    public var importRosterFile: @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview
    public var importResultsFile: @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview
    public var importBackup: @Sendable (_ url: URL) async throws -> Project
    public var prepareBackup: @Sendable (_ project: Project) async throws -> URL
    public var prepareReportExport: @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL

    public init(
        listProjects: @escaping @Sendable () async throws -> [ProjectSummary],
        createProject: @escaping @Sendable () async throws -> ProjectSummary,
        loadProject: @escaping @Sendable (_ id: String) async throws -> Project,
        saveProject: @escaping @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project,
        importRosterFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview,
        importResultsFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview,
        importBackup: @escaping @Sendable (_ url: URL) async throws -> Project,
        prepareBackup: @escaping @Sendable (_ project: Project) async throws -> URL,
        prepareReportExport: @escaping @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL
    ) {
        self.listProjects = listProjects
        self.createProject = createProject
        self.loadProject = loadProject
        self.saveProject = saveProject
        self.importRosterFile = importRosterFile
        self.importResultsFile = importResultsFile
        self.importBackup = importBackup
        self.prepareBackup = prepareBackup
        self.prepareReportExport = prepareReportExport
    }
}

extension ProjectStoreClient: DependencyKey {
    public static let liveValue = ProjectStoreClient(
        listProjects: {
            let store = try FileProjectStore.applicationSupport()
            return try await store.listProjects().map(projectSummary).sorted { $0.updatedAt > $1.updatedAt }
        },
        createProject: {
            let store = try FileProjectStore.applicationSupport()
            let now = milliseconds(Date())
            let project = Project(
                metadata: ProjectMetadata(
                    id: UUID().uuidString,
                    name: "Untitled Project",
                    term: "Term 1",
                    yearLevel: .year5,
                    createdAt: now,
                    updatedAt: now,
                    selectedSubjects: [:],
                    useFirstNameOnly: true
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
        importBackup: { url in
            try withSecurityScopedAccess(to: url) {
                try loadProjectBackupFile(from: url).project
            }
        },
        prepareBackup: { project in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("CommenterIOSExports", isDirectory: true)
            return try prepareProjectBackupFile(project: project, directory: directory).url
        },
        prepareReportExport: { project, format in
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("CommenterIOSExports", isDirectory: true)
            switch format {
            case .docx:
                return try prepareReportDocumentFile(project: project, format: format, directory: directory).url
            case .xlsx, .xls:
                return try prepareReviewWorkbookFile(project: project, format: format, directory: directory).url
            case .csv, .backupJSON:
                throw ReportExportPreparationError.unsupportedFormat(format)
            }
        }
    )

    public static let testValue = ProjectStoreClient(
        listProjects: {
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        createProject: {
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        loadProject: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        saveProject: { _, _, _, _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        importRosterFile: { _, _ in
            throw ImportExportError.unavailable(format: .csv, reason: "Project store test dependency was not provided.")
        },
        importResultsFile: { _, _ in
            throw ImportExportError.unavailable(format: .csv, reason: "Project store test dependency was not provided.")
        },
        importBackup: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        prepareBackup: { _ in
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        prepareReportExport: { _, format in
            throw ImportExportError.unavailable(format: format, reason: "Project store test dependency was not provided.")
        }
    )
}

public extension DependencyValues {
    var projectStoreClient: ProjectStoreClient {
        get { self[ProjectStoreClient.self] }
        set { self[ProjectStoreClient.self] = newValue }
    }
}

private func projectSummary(_ project: Project) -> ProjectSummary {
    ProjectSummary(
        id: project.metadata.id,
        name: project.metadata.name,
        term: project.metadata.term,
        updatedAt: project.metadata.updatedAt,
        revision: project.metadata.persistence?.revision
    )
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
