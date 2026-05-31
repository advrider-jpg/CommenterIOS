import CommenterDomain
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

    public init(
        listProjects: @escaping @Sendable () async throws -> [ProjectSummary],
        createProject: @escaping @Sendable () async throws -> ProjectSummary
    ) {
        self.listProjects = listProjects
        self.createProject = createProject
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
        }
    )

    public static let testValue = ProjectStoreClient(
        listProjects: {
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
        },
        createProject: {
            throw ProjectStoreError.unavailable("Project store test dependency was not provided.")
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
