import ComposableArchitecture
import Foundation

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .projects
        public var datasetStatus: DatasetStatus = .notLoaded
        public var projectStorageStatus: ProjectStorageStatus = .notLoaded
        public var projects: [ProjectSummary] = []
        public var projectStorageMessage = "Checking local project storage."
        public var importExportMessage = "CSV, XLSX, XLS, DOCX, and backup workflows are MVP requirements but are not ported in this scaffold slice."

        public init() {}
    }

    public enum Tab: String, CaseIterable, Equatable, Sendable {
        case projects
        case worklist
        case support
    }

    public enum DatasetStatus: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded(DatasetSnapshot)
        case failed(String)
    }

    public enum ProjectStorageStatus: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded
        case creating
        case failed(String)
    }

    public enum Action: Equatable, Sendable {
        case task
        case tabSelected(Tab)
        case datasetLoaded(DatasetSnapshot)
        case datasetFailed(String)
        case projectStoreLoaded([ProjectSummary])
        case projectStoreFailed(String)
        case createProjectTapped
        case projectCreateSaved(ProjectSummary)
        case projectCreateFailed(String)
    }

    @Dependency(\.datasetClient) var datasetClient
    @Dependency(\.projectStoreClient) var projectStoreClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.datasetStatus = .loading
                state.projectStorageStatus = .loading
                state.projectStorageMessage = "Checking local project storage."
                return .run { send in
                    do {
                        await send(.datasetLoaded(try await datasetClient.load()))
                    } catch {
                        await send(.datasetFailed(error.localizedDescription))
                    }
                    do {
                        await send(.projectStoreLoaded(try await projectStoreClient.listProjects()))
                    } catch {
                        await send(.projectStoreFailed(error.localizedDescription))
                    }
                }

            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none

            case let .datasetLoaded(snapshot):
                state.datasetStatus = .loaded(snapshot)
                return .none

            case let .datasetFailed(message):
                state.datasetStatus = .failed(message)
                return .none

            case let .projectStoreLoaded(projects):
                state.projectStorageStatus = .loaded
                state.projects = projects.sorted { $0.updatedAt > $1.updatedAt }
                state.projectStorageMessage = projectStorageLoadedMessage(projectCount: projects.count)
                return .none

            case let .projectStoreFailed(message):
                state.projectStorageStatus = .failed(message)
                state.projectStorageMessage = message
                return .none

            case .createProjectTapped:
                guard case .loaded = state.projectStorageStatus else {
                    return .none
                }
                state.projectStorageStatus = .creating
                state.projectStorageMessage = "Creating and verifying a local project file."
                return .run { send in
                    do {
                        await send(.projectCreateSaved(try await projectStoreClient.createProject()))
                    } catch {
                        await send(.projectCreateFailed(error.localizedDescription))
                    }
                }

            case let .projectCreateSaved(summary):
                state.projectStorageStatus = .loaded
                state.projects.removeAll { $0.id == summary.id }
                state.projects.append(summary)
                state.projects.sort { $0.updatedAt > $1.updatedAt }
                state.projectStorageMessage = "Project saved locally and verified: \(summary.name)."
                return .none

            case let .projectCreateFailed(message):
                state.projectStorageStatus = .loaded
                state.projectStorageMessage = "Project could not be saved: \(message)"
                return .none
            }
        }
    }
}

private func projectStorageLoadedMessage(projectCount: Int) -> String {
    if projectCount == 0 {
        return "Project storage is available. No saved projects were found on this device."
    }
    let label = projectCount == 1 ? "project" : "projects"
    return "\(projectCount) saved \(label) loaded from local storage."
}
