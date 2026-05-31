import AppFeature
import ComposableArchitecture
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
    func testTaskLoadsDatasetAndRealProjectSummaries() async {
        let snapshot = DatasetSnapshot(
            hash: "dataset-hash",
            normalizedSourceHash: "source-hash",
            subjectCount: 2,
            componentCount: 10,
            recipeCount: 1,
            assembledVariantCount: 3,
            uniquenessGuardCount: 1,
            warnings: [],
            summary: "dataset summary"
        )
        let project = ProjectSummary(
            id: "p1",
            name: "Room 5",
            term: "Term 1",
            updatedAt: 2,
            revision: 4
        )
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient { snapshot }
            $0.projectStoreClient = ProjectStoreClient(
                listProjects: { [project] },
                createProject: { project }
            )
        }

        await store.send(.task) {
            $0.datasetStatus = .loading
            $0.projectStorageStatus = .loading
            $0.projectStorageMessage = "Checking local project storage."
        }
        await store.receive(.datasetLoaded(snapshot)) {
            $0.datasetStatus = .loaded(snapshot)
        }
        await store.receive(.projectStoreLoaded([project])) {
            $0.projectStorageStatus = .loaded
            $0.projects = [project]
            $0.projectStorageMessage = "1 saved project loaded from local storage."
        }
    }

    func testCreateProjectOnlyReportsSuccessAfterStoreReturnsSavedProject() async {
        let saved = ProjectSummary(
            id: "saved-id",
            name: "Untitled Project",
            term: "Term 1",
            updatedAt: 10,
            revision: 1
        )
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projectStorageMessage = "Project storage is available. No saved projects were found on this device."
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient {
                throw NSError(domain: "dataset-not-used", code: 1)
            }
            $0.projectStoreClient = ProjectStoreClient(
                listProjects: { [] },
                createProject: { saved }
            )
        }

        await store.send(.createProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.projectStorageMessage = "Creating and verifying a local project file."
        }
        await store.receive(.projectCreateSaved(saved)) {
            $0.projectStorageStatus = .loaded
            $0.projects = [saved]
            $0.projectStorageMessage = "Project saved locally and verified: Untitled Project."
        }
    }

    func testCreateProjectFailureDoesNotAppendAProject() async {
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient {
                throw NSError(domain: "dataset-not-used", code: 1)
            }
            $0.projectStoreClient = ProjectStoreClient(
                listProjects: { [] },
                createProject: {
                    throw TestSaveFailure()
                }
            )
        }

        await store.send(.createProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.projectStorageMessage = "Creating and verifying a local project file."
        }
        await store.receive(.projectCreateFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.projectStorageMessage = "Project could not be saved: Save failed for test."
        }
    }
}

private struct TestSaveFailure: LocalizedError {
    var errorDescription: String? {
        "Save failed for test."
    }
}
