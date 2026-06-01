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

        case .operationStatusDismissed:
            if case .dirty = state.operationStatus {
                return .none
            }
            state.operationStatus = .idle
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

        case .copyDiagnosticsTapped:
            let diagnostics = supportDiagnosticsText(state: state)
            state.operationStatus = .busy("Copying support diagnostics.")
            return .run { send in
                do {
                    try await clipboardClient.copy(diagnostics)
                    await send(.copyDiagnosticsSucceeded)
                } catch {
                    await send(.copyDiagnosticsFailed(error.localizedDescription))
                }
            }

        case .copyDiagnosticsSucceeded:
            state.operationStatus = .saved("Diagnostics copied to clipboard.")
            return .none

        case let .copyDiagnosticsFailed(message):
            state.operationStatus = .failed("Diagnostics could not be copied: \(message)")
            return .none

        default:
            return .none
        }
    }
}
