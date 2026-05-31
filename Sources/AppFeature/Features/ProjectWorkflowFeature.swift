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
            state.projectStorageStatus = .creating
            state.operationStatus = .busy("Creating and verifying a local project file.")
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
            state.workflowMessage = "\(project.metadata.name) is open."
            state.operationStatus = .saved("Project opened from verified local storage.")
            state.selectedTab = .worklist
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
            guard case .loaded = state.datasetStatus else {
                state.operationStatus = .failed("The bundled production dataset must load before reports can be generated.")
                return .none
            }
            state.projectStorageStatus = .generating
            state.operationStatus = .busy("Generating reports from the bundled production dataset.")
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
            state.operationStatus = .failed("Reports were not generated: \(message)")
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
}
