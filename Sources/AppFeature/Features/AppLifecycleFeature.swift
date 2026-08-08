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
                do {
                    try await projectStoreClient.purgeStalePreparedFiles()
                } catch {
                    await send(.stalePreparedFilePurgeFailed(userVisibleErrorMessage(error)))
                }
                do {
                    await send(.datasetLoaded(try await datasetClient.load()))
                } catch {
                    await send(.datasetFailed(userVisibleErrorMessage(error)))
                }
                do {
                    await send(.projectStoreLoaded(try await projectStoreClient.listProjectDiagnostics()))
                } catch {
                    await send(.projectStoreFailed(userVisibleErrorMessage(error)))
                }
                await send(.aiAvailabilityLoaded(await aiClient.availability()))
            }

        case let .tabSelected(tab):
            state.selectedTab = tab
            return .none

        case let .worklistFocusChanged(focus):
            state.worklistFocus = focus
            return .none

        case let .appIntentRouteReceived(route):
            state.selectedTab = .worklist
            switch route {
            case .aiReviewQueue:
                state.worklistFocus = .drafts
                if state.selectedProject == nil {
                    state.operationStatus = .cancelled("AI review opened, but no project is open. Open a project to review its AI previews.")
                } else if state.aiReviewQueueCount == 0 {
                    state.operationStatus = hasUnsavedChanges(state)
                        ? .dirty("AI review opened. No AI previews are waiting, and the current project still has unsaved changes.")
                        : .cancelled("AI review opened, but no AI previews are waiting for teacher review.")
                } else if hasUnsavedChanges(state) {
                    state.operationStatus = .dirty("AI review opened with \(state.aiReviewQueueCount) waiting \(state.aiReviewQueueCount == 1 ? "preview" : "previews"). Unsaved project changes still need to be saved.")
                } else {
                    state.operationStatus = .prepared("AI review opened with \(state.aiReviewQueueCount) waiting \(state.aiReviewQueueCount == 1 ? "preview" : "previews").")
                }

            case .reportPreparation:
                state.worklistFocus = .files
                guard let readiness = state.selectedProjectReadiness else {
                    state.operationStatus = .cancelled("Report preparation opened, but no project is open. Open a project before preparing files.")
                    return .none
                }
                if hasUnsavedChanges(state) {
                    state.operationStatus = .dirty("Report preparation opened. Save the current project changes before preparing files.")
                } else if readiness.expected > 0, readiness.ready == readiness.expected {
                    state.operationStatus = .prepared("Report preparation opened. All \(readiness.expected) reports are ready for file preparation.")
                } else {
                    state.operationStatus = .cancelled("Report preparation opened. \(readiness.ready) of \(readiness.expected) reports are currently export-ready.")
                }
            }
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

        case let .stalePreparedFilePurgeFailed(message):
            state.operationStatus = .failed("Old temporary prepared files could not be fully removed. Current project data was not changed, and cleanup will be tried again next launch. \(message)")
            return .none

        case .copyDiagnosticsTapped:
            let diagnostics = supportDiagnosticsText(state: state, redaction: .redacted)
            state.operationStatus = .busy("Copying support diagnostics.")
            return .run { send in
                do {
                    try await clipboardClient.copy(diagnostics)
                    await send(.copyDiagnosticsSucceeded)
                } catch {
                    await send(.copyDiagnosticsFailed(userVisibleErrorMessage(error)))
                }
            }

        case .copyDiagnosticsSucceeded:
            state.operationStatus = .saved("Diagnostics copied to clipboard.")
            return .none

        case let .copyDiagnosticsFailed(message):
            state.operationStatus = .failed("Diagnostics could not be copied: \(message)")
            return .none

        case let .invalidProjectSupportCopyTapped(recordID):
            guard case .loaded = state.projectStorageStatus else {
                state.operationStatus = .failed("Wait for local project storage to finish before preparing a damaged-record support copy.")
                return .none
            }
            guard state.pendingImport == nil,
                  state.activeAIRequest == nil,
                  !state.isBulkAIRevisionRunning
            else {
                state.operationStatus = .failed("Finish or cancel the current project operation before preparing a damaged-record support copy.")
                return .none
            }
            guard state.preparedFile == nil else {
                state.operationStatus = .failed("Save, share, or dismiss the existing prepared file before preparing a damaged-record support copy.")
                return .none
            }
            let preparedAt = dateClient.nowMilliseconds()
            state.projectStorageStatus = .preparingFile
            state.operationStatus = .busy("Preparing an exact raw copy of the damaged saved-work record.")
            return .run { send in
                do {
                    let copy = try await projectStoreClient.prepareInvalidProjectSupportCopy(recordID)
                    await send(.invalidProjectSupportCopyPrepared(copy, preparedAt))
                } catch {
                    await send(.invalidProjectSupportCopyFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .invalidProjectSupportCopyPrepared(copy, preparedAt):
            state.projectStorageStatus = .loaded
            state.preparedFile = PreparedFile(
                url: copy.fileURL,
                label: copy.warning,
                purpose: .damagedRecordSupportCopy,
                preparedAtMilliseconds: preparedAt,
                projectID: nil
            )
            state.operationStatus = .prepared(copy.warning)
            return .none

        case let .invalidProjectSupportCopyFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("The damaged-record support copy could not be prepared. The original saved work was not changed. \(message)")
            return .none

        case let .invalidProjectRemovalConfirmed(recordID):
            guard case .loaded = state.projectStorageStatus else {
                state.operationStatus = .failed("Wait for local project storage to finish before removing damaged saved work.")
                return .none
            }
            guard state.pendingImport == nil,
                  state.activeAIRequest == nil,
                  !state.isBulkAIRevisionRunning
            else {
                state.operationStatus = .failed("Finish or cancel the current project operation before removing damaged saved work.")
                return .none
            }
            state.projectStorageStatus = .deleting
            state.operationStatus = .busy("Removing damaged saved work from the active project list while retaining its recovery material.")
            return .run { send in
                do {
                    await send(.invalidProjectRemoved(try await projectStoreClient.removeInvalidProject(recordID)))
                } catch {
                    await send(.invalidProjectRemovalFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .invalidProjectRemoved(diagnostics):
            state.projectStorageStatus = .loaded
            state.projects = sortedProjects(diagnostics.projects)
            state.invalidProjectRecords = diagnostics.invalidProjects
            state.projectStorageMessage = projectStorageLoadedMessage(
                projectCount: diagnostics.projects.count,
                invalidProjectCount: diagnostics.invalidProjects.count
            )
            state.operationStatus = .saved("Damaged saved work was removed from active projects. Its local recovery material was retained in the app's quarantine area.")
            return .none

        case let .invalidProjectRemovalFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("Damaged saved work could not be removed, so it remains in local storage. \(message)")
            return .none

        default:
            return .none
        }
    }
}
