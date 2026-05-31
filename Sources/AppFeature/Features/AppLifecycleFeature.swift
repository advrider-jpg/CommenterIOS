import ComposableArchitecture

extension AppFeature {
    func reduceAppLifecycle(_ state: inout State, _ action: Action) -> Effect<Action> {
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
            state.projects = sortedProjects(projects)
            state.projectStorageMessage = projectStorageLoadedMessage(projectCount: projects.count)
            return .none

        case let .projectStoreFailed(message):
            state.projectStorageStatus = .failed(message)
            state.projectStorageMessage = message
            return .none

        default:
            return .none
        }
    }
}
