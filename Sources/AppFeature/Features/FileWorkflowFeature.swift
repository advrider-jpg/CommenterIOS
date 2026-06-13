import CommentEngine
import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceFileWorkflow(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .rosterImportPicked(url):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before importing a roster.")
                return .none
            }
            guard canStartFileWorkflow(state: &state, label: "roster import") else { return .none }
            state.projectStorageStatus = .importing
            state.activeImportKind = .roster
            state.rosterImportState = .validating("Validating roster import before changing the project.")
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
                        recoveryReason: .beforeSave,
                        kind: .roster,
                        acceptedRows: preview.acceptedRows,
                        sourceFormat: preview.sourceFormat
                    )))
                } catch {
                    await send(.importFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .resultsImportPicked(url):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before importing results.")
                return .none
            }
            guard canStartFileWorkflow(state: &state, label: "results import") else { return .none }
            let prerequisites = resultsImportPrerequisiteMessages(project)
            guard prerequisites.isEmpty else {
                state.resultsImportState = .failed(prerequisites.joined(separator: " "))
                state.operationStatus = .failed("Results import is unavailable: \(prerequisites.joined(separator: " "))")
                return .none
            }
            state.projectStorageStatus = .importing
            state.activeImportKind = .results
            state.resultsImportState = .validating("Validating results import before changing the project.")
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
                        recoveryReason: .beforeSave,
                        kind: .results,
                        acceptedRows: preview.acceptedRows,
                        sourceFormat: preview.sourceFormat
                    )))
                } catch {
                    await send(.importFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .backupImportPicked(url):
            guard canStartFileWorkflow(state: &state, label: "backup import") else { return .none }
            state.projectStorageStatus = .importing
            state.activeImportKind = .backup
            state.operationStatus = .busy("Validating backup JSON before saving it locally.")
            return .run { send in
                do {
                    let imported = try await projectStoreClient.importBackup(url, nil)
                    await send(.importPreviewPrepared(PendingImport(
                        project: imported,
                        title: "Review backup import",
                        detail: "\(imported.metadata.name) was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
                        successMessage: "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
                        expectedRevision: nil,
                        recoveryReason: .beforeImportReplace,
                        kind: .backup,
                        acceptedRows: 1,
                        sourceFormat: .backupJSON
                    )))
                } catch BackupError.encryptedPasswordRequired {
                    await send(.encryptedBackupPasswordRequired(url))
                } catch {
                    await send(.importFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .encryptedBackupPasswordRequired(url):
            state.projectStorageStatus = .loaded
            state.activeImportKind = nil
            state.pendingEncryptedBackupURL = url
            state.operationStatus = .idle
            return .none

        case let .backupPasswordEntered(url, password):
            guard state.pendingEncryptedBackupURL == url else { return .none }
            guard canStartFileWorkflow(state: &state, label: "encrypted backup import") else { return .none }
            state.pendingEncryptedBackupURL = nil
            state.projectStorageStatus = .importing
            state.activeImportKind = .backup
            state.operationStatus = .busy("Decrypting and validating encrypted backup before saving locally.")
            return .run { send in
                do {
                    let imported = try await projectStoreClient.importBackup(url, password)
                    await send(.importPreviewPrepared(PendingImport(
                        project: imported,
                        title: "Review encrypted backup import",
                        detail: "\(imported.metadata.name) was decrypted and validated. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
                        successMessage: "Encrypted backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
                        expectedRevision: nil,
                        recoveryReason: .beforeImportReplace,
                        kind: .backup,
                        acceptedRows: 1,
                        sourceFormat: .backupJSON
                    )))
                } catch BackupError.encryptedCouldNotDecrypt, BackupError.encryptedPasswordRequired {
                    await send(.importFailed("The encrypted backup could not be opened. Check the backup password and try again."))
                } catch {
                    await send(.importFailed(userVisibleErrorMessage(error)))
                }
            }

        case .backupPasswordCancelled:
            state.pendingEncryptedBackupURL = nil
            state.projectStorageStatus = .loaded
            state.activeImportKind = nil
            state.operationStatus = .cancelled("Encrypted backup import cancelled.")
            return .none

        case .importCancelled:
            state.projectStorageStatus = .loaded
            if state.activeImportKind == .roster {
                state.rosterImportState = .failed("Roster import cancelled. No project data changed.")
            } else if state.activeImportKind == .results {
                state.resultsImportState = .failed("Results import cancelled. No project data changed.")
            }
            state.activeImportKind = nil
            state.pendingImport = nil
            state.operationStatus = .cancelled("Import cancelled. No project data changed.")
            return .none

        case let .importPreviewPrepared(preview):
            let preview = previewWithCurrentExpectedRevision(preview, summaries: state.projects)
            state.projectStorageStatus = .loaded
            state.pendingImport = preview
            state.selectedTab = .worklist
            state.activeImportKind = nil
            if preview.kind == .roster {
                state.rosterImportState = .previewReady(count: preview.acceptedRows, source: importSourceLabel(preview.sourceFormat))
            } else if preview.kind == .results {
                state.resultsImportState = .previewReady(count: preview.acceptedRows, source: importSourceLabel(preview.sourceFormat))
            }
            state.operationStatus = .prepared(preview.detail)
            state.workflowMessage = preview.detail
            return .none

        case .confirmImportTapped:
            guard let preview = state.pendingImport else {
                state.operationStatus = .failed("No validated import is waiting for confirmation.")
                return .none
            }
            if preview.kind == .backup {
                let collision = getBackupCollisionKind(
                    projectId: preview.project.metadata.id,
                    existingIds: state.projects.map(\.id),
                    invalidIds: state.invalidProjectRecords.map(\.id)
                )
                if collision == .invalid {
                    state.pendingImport = nil
                    state.projectStorageStatus = .loaded
                    state.activeImportKind = nil
                    state.operationStatus = .failed("A damaged local project with this ID exists. Remove the invalid record from Support diagnostics before importing this backup.")
                    return .none
                }
            }
            state.projectStorageStatus = .importing
            state.activeImportKind = preview.kind
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
                    await send(.importFailed(userVisibleErrorMessage(error)))
                }
            }

        case .importPreviewCancelled:
            if let pendingImport = state.pendingImport {
                if pendingImport.kind == .roster {
                    state.rosterImportState = .failed("Roster import preview cancelled. No project data changed.")
                } else if pendingImport.kind == .results {
                    state.resultsImportState = .failed("Results import preview cancelled. No project data changed.")
                }
            }
            state.projectStorageStatus = .loaded
            state.activeImportKind = nil
            state.pendingImport = nil
            state.operationStatus = .cancelled("Import preview cancelled. No project data changed.")
            return .none

        case let .importCommitted(project, message):
            let committedImport = state.pendingImport
            state.pendingImport = nil
            state.activeImportKind = nil
            if committedImport?.kind == .roster {
                state.rosterImportState = .success(count: committedImport?.acceptedRows ?? 0, source: importSourceLabel(committedImport?.sourceFormat))
            } else if committedImport?.kind == .results {
                state.resultsImportState = .success(count: committedImport?.acceptedRows ?? 0, source: importSourceLabel(committedImport?.sourceFormat))
            }
            acceptVerifiedProject(&state, project: project, message: message)
            state.projects.removeAll { $0.id == project.metadata.id }
            state.projects.append(projectSummary(project))
            state.projects = sortedProjects(state.projects)
            return .none

        case let .importFailed(message):
            let activeKind = state.activeImportKind ?? state.pendingImport?.kind
            state.projectStorageStatus = .loaded
            state.pendingImport = nil
            state.activeImportKind = nil
            if activeKind == .roster {
                if isZeroAcceptedRowsMessage(message, rowLabel: "student") {
                    state.rosterImportState = .zeroValidRecords(message)
                } else {
                    state.rosterImportState = .failed(message)
                }
            } else if activeKind == .results {
                if isZeroAcceptedRowsMessage(message, rowLabel: "result") {
                    state.resultsImportState = .zeroValidRecords(message)
                } else {
                    state.resultsImportState = .failed(message)
                }
            }
            state.operationStatus = .failed("Import failed before a verified commit. Check local storage before retrying: \(message)")
            return .none

        case .prepareBackupTapped:
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before exporting a backup.")
                return .none
            }
            guard canStartFileWorkflow(state: &state, label: "backup preparation") else { return .none }
            guard !hasUnsavedChanges(state) else {
                state.operationStatus = .failed("Save current changes before preparing Backup JSON so the backup reflects verified local storage.")
                return .none
            }
            let previousPreparedURL = state.preparedFile?.url
            state.projectStorageStatus = .preparingFile
            state.preparedFile = nil
            state.operationStatus = .busy("Preparing and verifying backup JSON.")
            let preparedAt = dateClient.nowMilliseconds()
            return .run { send in
                if let previousPreparedURL {
                    try? await projectStoreClient.discardPreparedFile(previousPreparedURL)
                }
                do {
                    await send(.filePrepared(try await projectStoreClient.prepareBackup(project), "Verified backup JSON is ready to export or share.", .backupJSON, preparedAt))
                } catch {
                    await send(.filePreparationFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .prepareReportExportTapped(format):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before exporting reports.")
                return .none
            }
            guard canStartFileWorkflow(state: &state, label: "report export preparation") else { return .none }
            guard !hasUnsavedChanges(state) else {
                state.operationStatus = .failed("Save current changes before preparing report exports so files reflect verified local storage.")
                return .none
            }
            guard let readiness = state.selectedProjectReadiness, readiness.expected > 0, readiness.ready == readiness.expected else {
                let ready = state.selectedProjectReadiness?.ready ?? 0
                let expected = state.selectedProjectReadiness?.expected ?? 0
                state.operationStatus = .failed("Report exports are not ready. \(ready) of \(expected) draft comments are export-ready.")
                return .none
            }
            let previousPreparedURL = state.preparedFile?.url
            state.projectStorageStatus = .preparingFile
            state.preparedFile = nil
            state.operationStatus = .busy("Checking readiness and preparing \(format.rawValue.uppercased()) export.")
            let preparedAt = dateClient.nowMilliseconds()
            return .run { send in
                if let previousPreparedURL {
                    try? await projectStoreClient.discardPreparedFile(previousPreparedURL)
                }
                do {
                    await send(.filePrepared(try await projectStoreClient.prepareReportExport(project, format), "\(format.rawValue.uppercased()) export file is verified and ready.", format, preparedAt))
                } catch {
                    await send(.filePreparationFailed(userVisibleErrorMessage(error)))
                }
            }

        case let .filePrepared(url, label, format, preparedAt):
            state.projectStorageStatus = .loaded
            state.preparedFile = PreparedFile(url: url, label: label, format: format, preparedAtMilliseconds: preparedAt)
            state.lastPreparedFiles[format] = PreparedFileRecord(
                format: format,
                filename: url.lastPathComponent,
                label: label,
                preparedAtMilliseconds: preparedAt
            )
            state.operationStatus = .prepared(label)
            return .none

        case let .filePreparationFailed(message):
            state.projectStorageStatus = .loaded
            state.preparedFile = nil
            state.operationStatus = .failed("File could not be prepared: \(message)")
            return .none

        case let .fileExportSaved(url):
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            state.operationStatus = .busy("File saved to \(url.lastPathComponent). Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .saved("File saved to \(url.lastPathComponent). Temporary prepared copy was removed."),
                failurePrefix: "File saved to \(url.lastPathComponent), but the temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case .fileExportCancelled:
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            state.operationStatus = .busy("File export cancelled. Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .cancelled("File export cancelled. Temporary prepared copy was removed."),
                failurePrefix: "File export cancelled, but the temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case let .fileExportFailed(message):
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            state.operationStatus = .busy("File export failed: \(message). Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .failed("File export failed: \(message). Temporary prepared copy was removed."),
                failurePrefix: "File export failed: \(message). The temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case let .fileShareStarted(url):
            state.operationStatus = .busy("Opening native share sheet for \(url.lastPathComponent).")
            return .none

        case let .fileShareCompleted(url):
            let preparedURL = state.preparedFile?.url ?? url
            state.preparedFile = nil
            state.operationStatus = .busy("Share completed for \(url.lastPathComponent). Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .shared("Share completed for \(url.lastPathComponent). Temporary prepared copy was removed."),
                failurePrefix: "Share completed for \(url.lastPathComponent), but the temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case .fileShareCancelled:
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            state.operationStatus = .busy("Share cancelled. Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .cancelled("Share cancelled. Temporary prepared copy was removed."),
                failurePrefix: "Share cancelled, but the temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case let .fileShareFailed(message):
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            state.operationStatus = .busy("Share failed: \(message). Removing temporary prepared copy.")
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: .failed("Share failed: \(message). Temporary prepared copy was removed."),
                failurePrefix: "Share failed: \(message). The temporary prepared copy could not be removed",
                projectStoreClient: projectStoreClient
            )

        case .preparedFileDismissed:
            let preparedURL = state.preparedFile?.url
            state.preparedFile = nil
            if case .prepared = state.operationStatus {
                state.operationStatus = .idle
            }
            return discardPreparedFileEffect(
                preparedURL,
                successStatus: state.operationStatus,
                failurePrefix: "The dismissed prepared file could not be removed",
                projectStoreClient: projectStoreClient
            )

        case let .preparedFileDiscardCompleted(status):
            state.operationStatus = status
            return .none

        case let .preparedFileDiscardFailed(message):
            state.operationStatus = .failed(message)
            return .none

        default:
            return .none
        }
    }
}

private func discardPreparedFileEffect(
    _ url: URL?,
    successStatus: AppFeature.OperationStatus,
    failurePrefix: String,
    projectStoreClient: ProjectStoreClient
) -> Effect<AppFeature.Action> {
    guard let url else { return .send(.preparedFileDiscardCompleted(successStatus)) }
    return .run { send in
        do {
            try await projectStoreClient.discardPreparedFile(url)
            await send(.preparedFileDiscardCompleted(successStatus))
        } catch {
            await send(.preparedFileDiscardFailed("\(failurePrefix): \(userVisibleErrorMessage(error))"))
        }
    }
}

private func importCountLabel(_ count: Int, singular: String, plural: String) -> String {
    count == 1 ? "1 \(singular)" : "\(count) \(plural)"
}

private func resultsImportPrerequisiteMessages(_ project: Project) -> [String] {
    var messages: [String] = []
    if project.roster.isEmpty {
        messages.append("Add at least one student before importing results.")
    }
    if selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty {
        messages.append("Select at least one subject before importing results.")
    }
    return messages
}

private func isZeroAcceptedRowsMessage(_ message: String, rowLabel: String) -> Bool {
    let normalized = message.lowercased()
    return normalized.contains("no ") && normalized.contains("accepted")
}

private func canStartFileWorkflow(state: inout AppFeature.State, label: String) -> Bool {
    guard !isLongRunningProjectOperation(state.projectStorageStatus) else {
        state.operationStatus = .failed("Wait for the current local operation to finish before starting \(label).")
        return false
    }
    guard state.pendingImport == nil else {
        state.operationStatus = .failed("Confirm or cancel the pending import before starting \(label).")
        return false
    }
    return true
}

private func previewWithCurrentExpectedRevision(
    _ preview: AppFeature.PendingImport,
    summaries: [ProjectSummary]
) -> AppFeature.PendingImport {
    guard preview.kind == .backup else { return preview }
    var preview = preview
    preview.expectedRevision = summaries.first { $0.id == preview.project.metadata.id }?.revision
    return preview
}
