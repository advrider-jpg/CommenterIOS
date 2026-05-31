import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import ComposableArchitecture

extension AppFeature {
    func reduceFileWorkflow(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .rosterImportPicked(url):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before importing a roster.")
                return .none
            }
            state.projectStorageStatus = .importing
            state.operationStatus = .busy("Validating roster import before changing the project.")
            let expectedRevision = project.metadata.persistence?.revision
            return .run { send in
                do {
                    let preview = try await projectStoreClient.importRosterFile(url, project)
                    let importedCount = importCountLabel(preview.acceptedRows, singular: "student", plural: "students")
                    await send(.importPreviewPrepared(PendingImport(
                        project: preview.change.project,
                        title: "Review roster import",
                        detail: "\(importedCount) validated from \(preview.sourceFormat.rawValue.uppercased()). Confirm to save this roster import locally.",
                        successMessage: "Roster imported, saved, and verified.",
                        expectedRevision: expectedRevision,
                        recoveryReason: .beforeSave
                    )))
                } catch {
                    await send(.importFailed(error.localizedDescription))
                }
            }

        case let .resultsImportPicked(url):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before importing results.")
                return .none
            }
            state.projectStorageStatus = .importing
            state.operationStatus = .busy("Validating results import before changing the project.")
            let expectedRevision = project.metadata.persistence?.revision
            return .run { send in
                do {
                    let preview = try await projectStoreClient.importResultsFile(url, project)
                    let rowLabel = importCountLabel(preview.acceptedRows, singular: "result row", plural: "result rows")
                    await send(.importPreviewPrepared(PendingImport(
                        project: preview.change.project,
                        title: "Review results import",
                        detail: "\(rowLabel) validated from \(preview.sourceFormat.rawValue.uppercased()). Confirm to save these results locally.",
                        successMessage: "Results imported, saved, and verified.",
                        expectedRevision: expectedRevision,
                        recoveryReason: .beforeSave
                    )))
                } catch {
                    await send(.importFailed(error.localizedDescription))
                }
            }

        case let .backupImportPicked(url):
            state.projectStorageStatus = .importing
            state.operationStatus = .busy("Validating backup JSON before saving it locally.")
            return .run { send in
                do {
                    let imported = try await projectStoreClient.importBackup(url)
                    await send(.importPreviewPrepared(PendingImport(
                        project: imported,
                        title: "Review backup import",
                        detail: "\(imported.metadata.name) was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
                        successMessage: "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
                        expectedRevision: nil,
                        recoveryReason: .beforeImportReplace
                    )))
                } catch {
                    await send(.importFailed(error.localizedDescription))
                }
            }

        case .importCancelled:
            state.projectStorageStatus = .loaded
            state.pendingImport = nil
            state.operationStatus = .cancelled("Import cancelled. No project data changed.")
            return .none

        case let .importPreviewPrepared(preview):
            state.projectStorageStatus = .loaded
            state.pendingImport = preview
            state.selectedTab = .worklist
            state.operationStatus = .prepared(preview.detail)
            state.workflowMessage = preview.detail
            return .none

        case .confirmImportTapped:
            guard let preview = state.pendingImport else {
                state.operationStatus = .failed("No validated import is waiting for confirmation.")
                return .none
            }
            state.projectStorageStatus = .importing
            state.operationStatus = .busy("Saving confirmed import and verifying local storage.")
            return .run { send in
                do {
                    let saved = try await projectStoreClient.saveProject(
                        preview.project,
                        preview.expectedRevision,
                        true,
                        preview.recoveryReason
                    )
                    await send(.importCommitted(saved, preview.successMessage))
                } catch {
                    await send(.importFailed(error.localizedDescription))
                }
            }

        case .importPreviewCancelled:
            state.projectStorageStatus = .loaded
            state.pendingImport = nil
            state.operationStatus = .cancelled("Import preview cancelled. No project data changed.")
            return .none

        case let .importCommitted(project, message):
            state.pendingImport = nil
            acceptVerifiedProject(&state, project: project, message: message)
            state.projects.removeAll { $0.id == project.metadata.id }
            state.projects.append(projectSummary(project))
            state.projects = sortedProjects(state.projects)
            return .none

        case let .importFailed(message):
            state.projectStorageStatus = .loaded
            state.pendingImport = nil
            state.operationStatus = .failed("Import failed. Project data was left unchanged: \(message)")
            return .none

        case .prepareBackupTapped:
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before exporting a backup.")
                return .none
            }
            state.projectStorageStatus = .preparingFile
            state.preparedFile = nil
            state.operationStatus = .busy("Preparing and verifying backup JSON.")
            return .run { send in
                do {
                    await send(.filePrepared(try await projectStoreClient.prepareBackup(project), "Verified backup JSON is ready to export or share."))
                } catch {
                    await send(.filePreparationFailed(error.localizedDescription))
                }
            }

        case let .prepareReportExportTapped(format):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before exporting reports.")
                return .none
            }
            state.projectStorageStatus = .preparingFile
            state.preparedFile = nil
            state.operationStatus = .busy("Checking readiness and preparing \(format.rawValue.uppercased()) export.")
            return .run { send in
                do {
                    await send(.filePrepared(try await projectStoreClient.prepareReportExport(project, format), "\(format.rawValue.uppercased()) export file is verified and ready."))
                } catch {
                    await send(.filePreparationFailed(error.localizedDescription))
                }
            }

        case let .filePrepared(url, label):
            state.projectStorageStatus = .loaded
            state.preparedFile = PreparedFile(url: url, label: label)
            state.operationStatus = .prepared(label)
            return .none

        case let .filePreparationFailed(message):
            state.projectStorageStatus = .loaded
            state.preparedFile = nil
            state.operationStatus = .failed("File could not be prepared: \(message)")
            return .none

        case let .fileExportSaved(url):
            state.operationStatus = .saved("File saved to \(url.lastPathComponent).")
            return .none

        case .fileExportCancelled:
            state.operationStatus = .cancelled("File export cancelled. No saved-file success was recorded.")
            return .none

        case let .fileExportFailed(message):
            state.operationStatus = .failed("File export failed: \(message)")
            return .none

        case .preparedFileDismissed:
            state.preparedFile = nil
            return .none

        default:
            return .none
        }
    }

}

private func importCountLabel(_ count: Int, singular: String, plural: String) -> String {
    count == 1 ? "1 \(singular)" : "\(count) \(plural)"
}
