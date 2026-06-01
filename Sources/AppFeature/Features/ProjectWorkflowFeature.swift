import CommentEngine
import CommenterDomain
import CommenterPersistence
import ComposableArchitecture
import Foundation

extension AppFeature {
    func reduceProjectWorkflow(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .createProjectTapped:
            guard case .loaded = state.projectStorageStatus else {
                state.operationStatus = .failed("Project storage is not available yet. Wait for local storage to load, or resolve the storage error shown on this screen.")
                return .none
            }
            guard !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before creating another project.")
                return .none
            }
            state.projectCreationDraft = ProjectCreationDraft()
            state.operationStatus = .idle
            return .none

        case let .projectCreationNameChanged(name):
            state.projectCreationDraft?.name = name
            return .none

        case let .projectCreationTermChanged(term):
            state.projectCreationDraft?.term = term
            return .none

        case let .projectCreationYearLevelChanged(yearLevel):
            state.projectCreationDraft?.yearLevel = yearLevel
            return .none

        case let .projectCreationUseFirstNameOnlyChanged(enabled):
            state.projectCreationDraft?.useFirstNameOnly = enabled
            return .none

        case .projectCreationCancelled:
            state.projectCreationDraft = nil
            state.operationStatus = .cancelled("Project creation cancelled. No project file was created.")
            return .none

        case .confirmCreateProjectTapped:
            guard case .loaded = state.projectStorageStatus else {
                state.operationStatus = .failed("Project storage is not available yet. Wait for local storage to load, or resolve the storage error shown on this screen.")
                return .none
            }
            guard let draft = state.projectCreationDraft else {
                state.operationStatus = .failed("Start a project creation flow before saving a new project.")
                return .none
            }
            guard !draft.normalizedName.isEmpty else {
                state.operationStatus = .failed("Enter a class or project name before creating the project.")
                return .none
            }
            state.projectStorageStatus = .creating
            state.operationStatus = .busy("Creating and verifying \(draft.normalizedName).")
            state.projectStorageMessage = "Creating and verifying \(draft.normalizedName)."
            return .run { send in
                do {
                    await send(.projectCreateSaved(try await projectStoreClient.createProject(draft)))
                } catch {
                    await send(.projectCreateFailed(error.localizedDescription))
                }
            }

        case let .projectCreateSaved(summary):
            state.projectCreationDraft = nil
            state.projectStorageStatus = .loaded
            state.projects.removeAll { $0.id == summary.id }
            state.projects.append(summary)
            state.projects = sortedProjects(state.projects)
            state.projectStorageMessage = "Project saved locally and verified: \(summary.name)."
            state.operationStatus = .saved("Project saved locally and verified: \(summary.name).")
            return .send(.projectTapped(summary.id))

        case let .projectCreateFailed(message):
            state.projectStorageStatus = .loaded
            state.projectStorageMessage = "Project could not be saved: \(message)"
            state.operationStatus = .failed("Project could not be saved: \(message)")
            return .none

        case let .projectTapped(id):
            guard !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before opening another project.")
                return .none
            }
            if state.selectedProject?.metadata.id != id, hasUnsavedChanges(state) {
                state.operationStatus = .failed("Save or reopen the current project before opening another project.")
                return .none
            }
            state.projectStorageStatus = .loadingProject
            state.operationStatus = .busy("Opening project.")
            return .run { send in
                do {
                    await send(.projectLoaded(try await projectStoreClient.loadProject(id)))
                } catch {
                    await send(.projectLoadFailed(error.localizedDescription))
                }
            }

        case let .projectLoaded(project):
            state.projectStorageStatus = .loaded
            state.selectedProject = project
            state.selectedProjectReadiness = getProjectReadiness(project)
            state.preparedFile = nil
            state.pendingImport = nil
            state.activeImportKind = nil
            state.hasUnsavedProjectChanges = false
            state.workflowMessage = "\(project.metadata.name) is open."
            state.operationStatus = .saved("Project opened from verified local storage.")
            state.selectedTab = .worklist
            state.rosterImportState = project.roster.isEmpty ? .neverImported : .loaded(count: project.roster.count, source: "verified local project")
            state.resultsImportState = project.results.isEmpty ? .neverImported : .loaded(count: project.results.count, source: "verified local project")
            return .none

        case let .projectLoadFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("Project could not be opened: \(message)")
            return .none

        case .saveProjectTapped:
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before saving.")
                return .none
            }
            guard !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Wait for the current local operation to finish before saving.")
                return .none
            }
            guard state.pendingImport == nil else {
                state.operationStatus = .failed("Confirm or cancel the pending import before saving.")
                return .none
            }
            state.projectStorageStatus = .saving
            state.operationStatus = .busy("Saving and verifying project.")
            let expectedRevision = project.metadata.persistence?.revision
            return saveProjectEffect(
                project,
                expectedRevision: expectedRevision,
                recoveryReason: .beforeSave,
                successMessage: "Project saved locally and verified."
            )

        case let .projectSaved(project, message):
            acceptVerifiedProject(&state, project: project, message: message)
            return .none

        case let .projectSaveFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("Project could not be saved: \(message)")
            return .none

        case .generateReportsTapped:
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before generating reports.")
                return .none
            }
            guard !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Wait for the current local operation to finish before generating draft comments.")
                return .none
            }
            let prerequisites = generationPrerequisiteMessages(project: project, datasetStatus: state.datasetStatus)
            guard prerequisites.isEmpty else {
                state.operationStatus = .failed("Draft comments cannot be generated yet: \(prerequisites.joined(separator: " "))")
                return .none
            }
            state.projectStorageStatus = .generating
            state.operationStatus = .busy("Generating deterministic draft comments from the bundled production dataset.")
            let expectedRevision = project.metadata.persistence?.revision
            return .run { send in
                do {
                    let generated = try await commentEngineClient.generateReports(project)
                    let saved = try await projectStoreClient.saveProject(generated.project, expectedRevision, true, .beforeSave)
                    await send(.reportsGeneratedAndSaved(saved, generationSuccessMessage(generated)))
                } catch {
                    await send(.reportsGenerationFailed(error.localizedDescription))
                }
            }

        case let .reportsGeneratedAndSaved(project, message):
            acceptVerifiedProject(&state, project: project, message: message)
            return .none

        case let .reportsGenerationFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("Draft comments were not generated: \(message)")
            return .none

        case let .deleteProjectConfirmed(id):
            guard let project = state.selectedProject, project.metadata.id == id else {
                state.operationStatus = .failed("Open the project before deleting it.")
                return .none
            }
            return deleteProjectEffect(&state, id: id, projectName: project.metadata.name, allowDirtySelectedProject: false)

        case let .projectListDeleteConfirmed(id):
            let projectName = state.projects.first(where: { $0.id == id })?.name
                ?? state.selectedProject?.metadata.name
                ?? "Project"
            return deleteProjectEffect(&state, id: id, projectName: projectName, allowDirtySelectedProject: false)

        case let .projectDeleted(id, projects, message):
            state.projectStorageStatus = .loaded
            state.projects = sortedProjects(projects)
            state.projectStorageMessage = projectStorageLoadedMessage(projectCount: projects.count)
            if state.selectedProject?.metadata.id == id {
                state.selectedProject = nil
                state.selectedProjectReadiness = nil
                state.hasUnsavedProjectChanges = false
                state.workflowMessage = "Open or create a project to manage roster, subjects, results, drafts, backups, and exports."
                state.selectedTab = .projects
            }
            state.preparedFile = nil
            state.pendingImport = nil
            state.activeImportKind = nil
            state.operationStatus = .saved(message)
            return .none

        case let .projectDeleteFailed(message):
            state.projectStorageStatus = .loaded
            state.operationStatus = .failed("Project could not be deleted: \(message)")
            return .none

        default:
            return .none
        }
    }

    func saveProjectEffect(
        _ project: Project,
        expectedRevision: Int?,
        recoveryReason: RecoveryReason,
        successMessage: String
    ) -> Effect<Action> {
        .run { send in
            do {
                let saved = try await projectStoreClient.saveProject(project, expectedRevision, true, recoveryReason)
                await send(.projectSaved(saved, successMessage))
            } catch {
                await send(.projectSaveFailed(error.localizedDescription))
            }
        }
    }

    private func deleteProjectEffect(
        _ state: inout State,
        id: String,
        projectName: String,
        allowDirtySelectedProject: Bool
    ) -> Effect<Action> {
        guard case .loaded = state.projectStorageStatus else {
            state.operationStatus = .failed("Wait for the current local operation to finish before deleting this project.")
            return .none
        }
        if let pendingImport = state.pendingImport {
            state.operationStatus = .failed("\(pendingImport.title) is waiting. Confirm or cancel the import before deleting this project.")
            return .none
        }
        if !allowDirtySelectedProject, state.selectedProject?.metadata.id == id, hasUnsavedChanges(state) {
            state.operationStatus = .failed("Save or reopen the project before deleting it so the recovery snapshot reflects verified local storage.")
            return .none
        }
        state.projectStorageStatus = .deleting
        state.preparedFile = nil
        state.pendingImport = nil
        state.activeImportKind = nil
        state.operationStatus = .busy("Creating a recovery snapshot and deleting the local project.")
        state.projectStorageMessage = "Creating a recovery snapshot and deleting the local project."
        return .run { send in
            do {
                let projects = try await projectStoreClient.deleteProject(id)
                await send(.projectDeleted(id, projects, "\(projectName) was deleted after a verified recovery snapshot was created."))
            } catch {
                await send(.projectDeleteFailed(error.localizedDescription))
            }
        }
    }
}
