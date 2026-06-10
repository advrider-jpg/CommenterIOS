import ComposableArchitecture

extension AppFeature {
    func reduceAppLifecycle(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .task:
            state.datasetStatus = .loading
            state.projectStorageStatus = .loading
            state.aiAvailabilityStatus = .checking
            state.projectStorageMessage = "Checking local project storage."
            return .run { send in
                await projectStoreClient.purgeStalePreparedFiles()
                do {
                    await send(.datasetLoaded(try await datasetClient.load()))
                } catch {
                    await send(.datasetFailed(error.localizedDescription))
                }
                do {
                    await send(.projectStoreLoaded(try await projectStoreClient.listProjectDiagnostics()))
                } catch {
                    await send(.projectStoreFailed(error.localizedDescription))
                }
                await send(.aiAvailabilityLoaded(await aiClient.availability()))
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

        case let .aiAvailabilityLoaded(availability):
            state.aiAvailabilityStatus = .checked(availability)
            return .none

        case let .aiAvailabilityFailed(message):
            state.aiAvailabilityStatus = .failed(message)
            return .none

        case let .projectStoreLoaded(diagnostics):
            state.projectStorageStatus = .loaded
            state.projects = sortedProjects(diagnostics.projects)
            state.invalidProjectRecords = diagnostics.invalidProjects
            state.projectStorageMessage = projectStorageLoadedMessage(
                projectCount: diagnostics.projects.count,
                invalidProjectCount: diagnostics.invalidProjects.count
            )
            return .none

        case let .projectStoreFailed(message):
            state.projectStorageStatus = .failed(message)
            state.invalidProjectRecords = []
            state.projectStorageMessage = message
            return .none

        case .copyDiagnosticsTapped:
            let diagnostics = supportDiagnosticsText(state: state, redaction: .redacted)
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
