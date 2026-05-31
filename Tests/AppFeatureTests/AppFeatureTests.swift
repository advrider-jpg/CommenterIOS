import AppFeature
import ComposableArchitecture
import CommentEngine
import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import Foundation
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
            $0.projectStoreClient = testProjectStoreClient(
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
        let savedProject = project(id: saved.id, name: saved.name, term: saved.term, updatedAt: saved.updatedAt, revision: saved.revision)
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projectStorageMessage = "Project storage is available. No saved projects were found on this device."
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient {
                throw NSError(domain: "dataset-not-used", code: 1)
            }
            $0.projectStoreClient = testProjectStoreClient(
                listProjects: { [] },
                createProject: { saved },
                loadProject: { _ in savedProject }
            )
        }

        await store.send(.createProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.operationStatus = .busy("Creating and verifying a local project file.")
            $0.projectStorageMessage = "Creating and verifying a local project file."
        }
        await store.receive(.projectCreateSaved(saved)) {
            $0.projectStorageStatus = .loaded
            $0.projects = [saved]
            $0.projectStorageMessage = "Project saved locally and verified: Untitled Project."
            $0.operationStatus = .saved("Project saved locally and verified: Untitled Project.")
        }
        await store.receive(.projectTapped(saved.id)) {
            $0.projectStorageStatus = .loadingProject
            $0.operationStatus = .busy("Opening project.")
        }
        await store.receive(.projectLoaded(savedProject)) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = savedProject
            $0.selectedProjectReadiness = getProjectReadiness(savedProject)
            $0.workflowMessage = "Untitled Project is open."
            $0.operationStatus = .saved("Project opened from verified local storage.")
            $0.selectedTab = .worklist
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
            $0.projectStoreClient = testProjectStoreClient(
                listProjects: { [] },
                createProject: {
                    throw TestSaveFailure()
                }
            )
        }

        await store.send(.createProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.operationStatus = .busy("Creating and verifying a local project file.")
            $0.projectStorageMessage = "Creating and verifying a local project file."
        }
        await store.receive(.projectCreateFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.projectStorageMessage = "Project could not be saved: Save failed for test."
            $0.operationStatus = .failed("Project could not be saved: Save failed for test.")
        }
    }

    func testCreateProjectUnavailableStorageFailsVisiblyWithoutCallingStore() async {
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .failed("Disk permission denied.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                createProject: {
                    await probe.record("unexpected-create")
                    throw TestUnexpectedSave()
                }
            )
        }

        await store.send(.createProjectTapped) {
            $0.operationStatus = .failed("Project storage is not available yet. Wait for local storage to load, or resolve the storage error shown on this screen.")
        }
        XCTAssertEqual(await probe.values(), [])
    }


    func testDeleteProjectCreatesRecoverySnapshotThenClearsOpenProject() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let other = ProjectSummary(
            id: "p2",
            name: "Room 6",
            term: "Term 2",
            updatedAt: 20,
            revision: 2
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projects = [projectSummary(original), other]
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)
        initial.workflowMessage = "Room 5 is open."
        initial.operationStatus = .saved("Project opened from verified local storage.")
        initial.selectedTab = .worklist
        initial.preparedFile = AppFeature.PreparedFile(url: URL(fileURLWithPath: "/tmp/old.docx"), label: "Old file")

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                deleteProject: { id in
                    XCTAssertEqual(id, "p1")
                    await probe.record("delete-p1")
                    return [other]
                }
            )
        }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.projectStorageStatus = .deleting
            $0.preparedFile = nil
            $0.pendingImport = nil
            $0.operationStatus = .busy("Creating a recovery snapshot and deleting the local project.")
            $0.projectStorageMessage = "Creating a recovery snapshot and deleting the local project."
        }
        await store.receive(.projectDeleted("p1", [other], "Room 5 was deleted after a verified recovery snapshot was created.")) {
            $0.projectStorageStatus = .loaded
            $0.projects = [other]
            $0.projectStorageMessage = "1 saved project loaded from local storage."
            $0.selectedProject = nil
            $0.selectedProjectReadiness = nil
            $0.workflowMessage = "Open or create a project to manage roster, subjects, results, drafts, backups, and exports."
            $0.selectedTab = .projects
            $0.operationStatus = .saved("Room 5 was deleted after a verified recovery snapshot was created.")
        }
        XCTAssertEqual(await probe.values(), ["delete-p1"])
    }

    func testDirtyProjectCannotBeDeletedUntilVerifiedStorageReflectsCurrentState() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                deleteProject: { _ in
                    await probe.record("unexpected-delete")
                    return []
                }
            )
        }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.operationStatus = .failed("Save or reopen the project before deleting it so the recovery snapshot reflects verified local storage.")
        }
        XCTAssertEqual(await probe.values(), [])
    }

    func testPendingImportBlocksProjectDeletion() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)
        initial.operationStatus = .saved("Project opened from verified local storage.")
        initial.pendingImport = AppFeature.PendingImport(
            project: original,
            title: "Roster import preview",
            detail: "1 row accepted.",
            successMessage: "Roster import saved.",
            expectedRevision: 3,
            recoveryReason: .beforeImportReplace
        )

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                deleteProject: { _ in
                    await probe.record("unexpected-delete")
                    return []
                }
            )
        }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.operationStatus = .failed("Roster import preview is waiting. Confirm or cancel the import before deleting this project.")
        }
        XCTAssertEqual(await probe.values(), [])
    }

    func testProjectYearLevelEditMarksProjectDirtyAndSaveUsesVerifiedStorePath() async {
        let original = project(id: "p1", name: "Room 5", revision: 2)
        var edited = original
        edited.metadata.yearLevel = .mixed
        var saved = edited
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 3)

        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, edited)
                    XCTAssertEqual(expectedRevision, 2)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    return saved
                }
            )
        }

        await store.send(.projectYearLevelChanged(.mixed)) {
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.saveProjectTapped) {
            $0.projectStorageStatus = .saving
            $0.operationStatus = .busy("Saving and verifying project.")
        }
        await store.receive(.projectSaved(saved, "Project saved locally and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
    }

    func testManualMetadataEditsStayDirtyUntilVerifiedSaveReturns() async {
        let original = project(id: "p1", name: "Room 5", term: "Term 1", revision: 2)
        var edited = original
        edited.metadata.name = "Room 6"
        edited.metadata.term = "Term 2"
        edited.metadata.useFirstNameOnly = false
        var saved = edited
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 3)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)
        initial.projects = [projectSummary(original)]

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, edited)
                    XCTAssertEqual(expectedRevision, 2)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    await probe.record("verified-save")
                    return saved
                }
            )
        }

        await store.send(.projectNameChanged("Room 6")) {
            $0.selectedProject?.metadata.name = "Room 6"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.projectTermChanged("Term 2")) {
            $0.selectedProject?.metadata.term = "Term 2"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.useFirstNameOnlyChanged(false)) {
            $0.selectedProject?.metadata.useFirstNameOnly = false
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        XCTAssertEqual(await probe.values(), [])

        await store.send(.saveProjectTapped) {
            $0.projectStorageStatus = .saving
            $0.operationStatus = .busy("Saving and verifying project.")
        }
        await store.receive(.projectSaved(saved, "Project saved locally and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
        XCTAssertEqual(await probe.values(), ["verified-save"])
    }

    func testManualRosterSubjectResultAndReportEditsAreSavedOnlyThroughStoreResponse() async {
        var original = project(id: "p1", name: "Room 5", revision: 5)
        original.metadata.selectedSubjects = [
            "English": SelectedSubject(name: "English", allStrandsSelected: true),
            "Science": SelectedSubject(name: "Science", allStrandsSelected: true)
        ]
        original.roster = [
            Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5),
            Student(id: "s2", firstName: "Ben", lastName: "Fox", yearLevel: .year5)
        ]
        original.results = [
            AchievementResult(studentId: "s1", subject: "English", achievementLevel: .developing),
            AchievementResult(studentId: "s1", subject: "Science", achievementLevel: .atStandard),
            AchievementResult(studentId: "s2", subject: "English", achievementLevel: .beginning)
        ]
        original.reports = [
            GeneratedReport(studentId: "s1", subject: "English", text: "Draft", generatedAt: 1),
            GeneratedReport(studentId: "s1", subject: "Science", text: "Science draft", generatedAt: 1),
            GeneratedReport(studentId: "s2", subject: "English", text: "Ben draft", generatedAt: 1)
        ]
        var edited = original
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.selectedProjectReadiness = getProjectReadiness(original)
        let probe = WorkflowProbe()

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, edited)
                    XCTAssertEqual(expectedRevision, 5)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    await probe.record("verified-save")
                    var saved = edited
                    saved.metadata.persistence = ProjectPersistenceMetadata(revision: 6)
                    return saved
                }
            )
        }

        await store.send(.addStudentTapped) {
            edited.roster.append(Student(id: "student-3", firstName: "", lastName: "", yearLevel: .year5))
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentFirstNameChanged("student-3", "Cara")) {
            edited.roster[2].firstName = "Cara"
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentLastNameChanged("student-3", "Lee")) {
            edited.roster[2].lastName = "Lee"
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.deleteStudentTapped("s2")) {
            edited.roster.removeAll { $0.id == "s2" }
            edited.results.removeAll { $0.studentId == "s2" }
            edited.reports.removeAll { $0.studentId == "s2" }
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.subjectToggled("Science")) {
            edited.metadata.selectedSubjects.removeValue(forKey: "Science")
            edited.results.removeAll { $0.subject == "Science" }
            edited.reports.removeAll { $0.subject == "Science" }
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.achievementLevelChanged("student-3", "English", .aboveStandard)) {
            edited.results.append(AchievementResult(studentId: "student-3", subject: "English", achievementLevel: .aboveStandard))
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.focusChanged("student-3", "English", "Writing")) {
            edited.results[1].focusStrand = "Writing"
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.reportManualEditChanged("s1", "English", "Manual teacher edit.")) {
            edited.reports[0].manualEdit = "Manual teacher edit."
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.reportLockChanged("s1", "English", true)) {
            edited.reports[0].isLocked = true
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        XCTAssertEqual(await probe.values(), [])

        await store.send(.saveProjectTapped) {
            $0.projectStorageStatus = .saving
            $0.operationStatus = .busy("Saving and verifying project.")
        }
        var saved = edited
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 6)
        await store.receive(.projectSaved(saved, "Project saved locally and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
        XCTAssertEqual(await probe.values(), ["verified-save"])
    }

    func testManualEditSaveFailureDoesNotReportSuccessOrReplaceDirtyProject() async {
        let original = project(id: "p1", name: "Room 5", revision: 2)
        var dirty = original
        dirty.metadata.name = "Unsaved Room"
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.projects = [projectSummary(original)]

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, dirty)
                    XCTAssertEqual(expectedRevision, 2)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    throw TestSaveFailure()
                }
            )
        }

        await store.send(.projectNameChanged("Unsaved Room")) {
            $0.selectedProject = dirty
            $0.selectedProjectReadiness = getProjectReadiness(dirty)
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.saveProjectTapped) {
            $0.projectStorageStatus = .saving
            $0.operationStatus = .busy("Saving and verifying project.")
        }
        await store.receive(.projectSaveFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("Project could not be saved: Save failed for test.")
        }
    }

    func testRosterImportPickPreparesPreviewWithoutSavingThenConfirmCommits() async {
        let original = project(id: "p1", name: "Room 5", revision: 7)
        var imported = original
        imported.roster = [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
        var saved = imported
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 8)
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review roster import",
            detail: "1 student validated from XLSX. Confirm to save this roster import locally.",
            successMessage: "Roster imported, saved, and verified.",
            expectedRevision: 7,
            recoveryReason: .beforeSave
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, imported)
                    XCTAssertEqual(expectedRevision, 7)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    await probe.record("verified-save")
                    return saved
                },
                importRosterFile: { _, project in
                    XCTAssertEqual(project, original)
                    await probe.record("parsed-roster")
                    return importPreview(format: .xlsx, kind: .roster, count: 1, project: imported)
                }
            )
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.xlsx"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("1 student validated from XLSX. Confirm to save this roster import locally.")
            $0.workflowMessage = "1 student validated from XLSX. Confirm to save this roster import locally."
        }
        XCTAssertEqual(await probe.values(), ["parsed-roster"])

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importCommitted(saved, "Roster imported, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved("Roster imported, saved, and verified.")
            $0.workflowMessage = "Roster imported, saved, and verified."
            $0.projects = [projectSummary(saved)]
        }
        XCTAssertEqual(await probe.values(), ["parsed-roster", "verified-save"])
    }

    func testRosterImportFailureLeavesSelectedProjectUnchanged() async {
        let original = project(id: "p1", name: "Room 5", revision: 7)
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                importRosterFile: { _, _ in throw TestSaveFailure() }
            )
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/bad-roster.xls"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        await store.receive(.importFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Save failed for test.")
        }
    }

    func testGenerationReportsSuccessOnlyAfterGenerationAndVerifiedSave() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        var generated = original
        generated.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Ava reads with clear expression.",
                generatedAt: 10
            )
        ]
        var saved = generated
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 4)
        var initial = AppFeature.State()
        initial.datasetStatus = .loaded(DatasetSnapshot(hash: "h", normalizedSourceHash: "n", subjectCount: 1, componentCount: 1, recipeCount: 1, assembledVariantCount: 1, uniquenessGuardCount: 0, warnings: [], summary: "ok"))
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { project in
                XCTAssertEqual(project, original)
                return CommentGenerationResult(project: generated, generatedCount: 1, skippedLockedCount: 0)
            }
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, generated)
                    XCTAssertEqual(expectedRevision, 3)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    return saved
                }
            )
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating reports from the bundled production dataset.")
        }
        await store.receive(.reportsGeneratedAndSaved(saved, "1 report generated, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved("1 report generated, saved, and verified.")
            $0.workflowMessage = "1 report generated, saved, and verified."
            $0.projects = [projectSummary(saved)]
        }
    }

    func testGenerationSuccessMessageReportsLockedSkipsTruthfully() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        var generated = original
        generated.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Ava reads with clear expression.",
                generatedAt: 10
            )
        ]
        var saved = generated
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 4)
        var initial = AppFeature.State()
        initial.datasetStatus = .loaded(DatasetSnapshot(hash: "h", normalizedSourceHash: "n", subjectCount: 1, componentCount: 1, recipeCount: 1, assembledVariantCount: 1, uniquenessGuardCount: 0, warnings: [], summary: "ok"))
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { project in
                XCTAssertEqual(project, original)
                return CommentGenerationResult(project: generated, generatedCount: 1, skippedLockedCount: 1)
            }
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, generated)
                    XCTAssertEqual(expectedRevision, 3)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    return saved
                }
            )
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating reports from the bundled production dataset.")
        }
        await store.receive(.reportsGeneratedAndSaved(saved, "1 report generated, 1 locked report left unchanged, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved("1 report generated, 1 locked report left unchanged, saved, and verified.")
            $0.workflowMessage = "1 report generated, 1 locked report left unchanged, saved, and verified."
            $0.projects = [projectSummary(saved)]
        }
    }

    func testPrepareReportExportOnlyReportsPreparedAfterClientReturnsURL() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let url = URL(fileURLWithPath: "/tmp/reports.docx")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                prepareReportExport: { project, format in
                    XCTAssertEqual(project, original)
                    XCTAssertEqual(format, .docx)
                    return url
                }
            )
        }

        await store.send(.prepareReportExportTapped(.docx)) {
            $0.projectStorageStatus = .preparingFile
            $0.operationStatus = .busy("Checking readiness and preparing DOCX export.")
        }
        await store.receive(.filePrepared(url, "DOCX export file is verified and ready.")) {
            $0.projectStorageStatus = .loaded
            $0.preparedFile = AppFeature.PreparedFile(url: url, label: "DOCX export file is verified and ready.")
            $0.operationStatus = .prepared("DOCX export file is verified and ready.")
        }
    }

    func testBackupImportPickPreparesPreviewWithoutSavingThenConfirmCommits() async {
        let url = URL(fileURLWithPath: "/tmp/room-5.commenter-backup.json")
        let imported = project(id: "imported-id", name: "Imported Room", revision: nil)
        var saved = imported
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 1)
        let message = "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared."
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review backup import",
            detail: "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
            successMessage: message,
            expectedRevision: nil,
            recoveryReason: .beforeImportReplace
        )
        let probe = WorkflowProbe()

        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                importBackup: { pickedURL in
                    XCTAssertEqual(pickedURL, url)
                    await probe.record("parsed-backup")
                    return imported
                },
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, imported)
                    XCTAssertNil(expectedRevision)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeImportReplace)
                    await probe.record("verified-save")
                    return saved
                }
            )
        }

        await store.send(.backupImportPicked(url)) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating backup JSON before saving it locally.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.")
            $0.workflowMessage = "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement."
        }
        XCTAssertEqual(await probe.values(), ["parsed-backup"])

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importCommitted(saved, message)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved(message)
            $0.workflowMessage = message
            $0.projects = [projectSummary(saved)]
        }
        XCTAssertEqual(await probe.values(), ["parsed-backup", "verified-save"])
    }

    func testBackupImportSaveFailureAfterConfirmClearsPreviewAndDoesNotReportSuccess() async {
        let url = URL(fileURLWithPath: "/tmp/room-5.commenter-backup.json")
        let original = project(id: "p1", name: "Room 5", revision: 7)
        let imported = project(id: "p1", name: "Imported Room", revision: nil)
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review backup import",
            detail: "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
            successMessage: "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
            expectedRevision: nil,
            recoveryReason: .beforeImportReplace
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.projects = [projectSummary(original)]

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                importBackup: { pickedURL in
                    XCTAssertEqual(pickedURL, url)
                    await probe.record("parsed-backup")
                    return imported
                },
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, imported)
                    XCTAssertNil(expectedRevision)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeImportReplace)
                    await probe.record("failed-save")
                    throw TestSaveFailure()
                }
            )
        }

        await store.send(.backupImportPicked(url)) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating backup JSON before saving it locally.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.")
            $0.workflowMessage = "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement."
        }
        XCTAssertEqual(await probe.values(), ["parsed-backup"])

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Save failed for test.")
        }
        XCTAssertEqual(await probe.values(), ["parsed-backup", "failed-save"])
    }

    func testRosterImportSaveFailureAfterConfirmClearsPreviewAndLeavesProjectUnchanged() async {
        let original = project(id: "p1", name: "Room 5", revision: 7)
        var imported = original
        imported.roster = [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review roster import",
            detail: "1 student validated from CSV. Confirm to save this roster import locally.",
            successMessage: "Roster imported, saved, and verified.",
            expectedRevision: 7,
            recoveryReason: .beforeSave
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.projects = [projectSummary(original)]

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, imported)
                    XCTAssertEqual(expectedRevision, 7)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    await probe.record("failed-save")
                    throw TestSaveFailure()
                },
                importRosterFile: { _, project in
                    XCTAssertEqual(project, original)
                    await probe.record("parsed-roster")
                    return importPreview(format: .csv, kind: .roster, count: 1, project: imported)
                }
            )
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.csv"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("1 student validated from CSV. Confirm to save this roster import locally.")
            $0.workflowMessage = "1 student validated from CSV. Confirm to save this roster import locally."
        }
        XCTAssertEqual(await probe.values(), ["parsed-roster"])

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Save failed for test.")
        }
        XCTAssertEqual(await probe.values(), ["parsed-roster", "failed-save"])
    }

    func testResultsImportPickPreparesPreviewWithoutSavingThenConfirmCommits() async {
        var original = project(id: "p1", name: "Room 5", revision: 4)
        original.roster = [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
        original.metadata.selectedSubjects = ["English": SelectedSubject(name: "English", allStrandsSelected: true)]
        var imported = original
        imported.results = [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)]
        var saved = imported
        saved.metadata.persistence = ProjectPersistenceMetadata(revision: 5)
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review results import",
            detail: "1 result row validated from XLSX. Confirm to save these results locally.",
            successMessage: "Results imported, saved, and verified.",
            expectedRevision: 4,
            recoveryReason: .beforeSave
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, recoveryReason in
                    XCTAssertEqual(project, imported)
                    XCTAssertEqual(expectedRevision, 4)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(recoveryReason, .beforeSave)
                    await probe.record("verified-save")
                    return saved
                },
                importResultsFile: { _, project in
                    XCTAssertEqual(project, original)
                    await probe.record("parsed-results")
                    return importPreview(format: .xlsx, kind: .results, count: 1, project: imported)
                }
            )
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.xlsx"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating results import before changing the project.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("1 result row validated from XLSX. Confirm to save these results locally.")
            $0.workflowMessage = "1 result row validated from XLSX. Confirm to save these results locally."
        }
        XCTAssertEqual(await probe.values(), ["parsed-results"])

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importCommitted(saved, "Results imported, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.selectedProject = saved
            $0.selectedProjectReadiness = getProjectReadiness(saved)
            $0.operationStatus = .saved("Results imported, saved, and verified.")
            $0.workflowMessage = "Results imported, saved, and verified."
            $0.projects = [projectSummary(saved)]
        }
        XCTAssertEqual(await probe.values(), ["parsed-results", "verified-save"])
    }

    func testImportPreviewCancelLeavesSelectedProjectUnchangedAndDoesNotSave() async {
        let original = project(id: "p1", name: "Room 5", revision: 7)
        var imported = original
        imported.roster = [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
        let preview = AppFeature.PendingImport(
            project: imported,
            title: "Review roster import",
            detail: "1 student validated from CSV. Confirm to save this roster import locally.",
            successMessage: "Roster imported, saved, and verified.",
            expectedRevision: 7,
            recoveryReason: .beforeSave
        )
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { _, _, _, _ in
                    await probe.record("unexpected-save")
                    throw TestUnexpectedSave()
                },
                importRosterFile: { _, project in
                    XCTAssertEqual(project, original)
                    await probe.record("parsed-roster")
                    return importPreview(format: .csv, kind: .roster, count: 1, project: imported)
                }
            )
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.csv"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        await store.receive(.importPreviewPrepared(preview)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = preview
            $0.operationStatus = .prepared("1 student validated from CSV. Confirm to save this roster import locally.")
            $0.workflowMessage = "1 student validated from CSV. Confirm to save this roster import locally."
        }
        await store.send(.importPreviewCancelled) {
            $0.pendingImport = nil
            $0.operationStatus = .cancelled("Import preview cancelled. No project data changed.")
        }
        XCTAssertEqual(await probe.values(), ["parsed-roster"])
    }

    func testResultsImportParseFailureDoesNotSaveOrReportSuccess() async {
        let original = project(id: "p1", name: "Room 5", revision: 4)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { _, _, _, _ in
                    await probe.record("unexpected-save")
                    throw TestUnexpectedSave()
                },
                importResultsFile: { _, project in
                    XCTAssertEqual(project, original)
                    await probe.record("failed-results-parse")
                    throw TestImportFailure()
                }
            )
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.xls"))) {
            $0.projectStorageStatus = .importing
            $0.operationStatus = .busy("Validating results import before changing the project.")
        }
        await store.receive(.importFailed("Import parse failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Import parse failed for test.")
        }
        XCTAssertEqual(await probe.values(), ["failed-results-parse"])
    }

    func testReportExportPreparationFailureClearsExistingPreparedFile() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let staleURL = URL(fileURLWithPath: "/tmp/old-report.docx")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original
        initial.preparedFile = AppFeature.PreparedFile(url: staleURL, label: "Old DOCX export file is verified and ready.")

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                prepareReportExport: { project, format in
                    XCTAssertEqual(project, original)
                    XCTAssertEqual(format, .xlsx)
                    throw TestFilePreparationFailure()
                }
            )
        }

        await store.send(.prepareReportExportTapped(.xlsx)) {
            $0.projectStorageStatus = .preparingFile
            $0.preparedFile = nil
            $0.operationStatus = .busy("Checking readiness and preparing XLSX export.")
        }
        await store.receive(.filePreparationFailed("File preparation failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("File could not be prepared: File preparation failed for test.")
        }
    }

    func testFileExporterAndShareCompletionStatusesDistinguishCompletedCancelledAndFailed() async {
        let preparedURL = URL(fileURLWithPath: "/tmp/reports.docx")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.preparedFile = AppFeature.PreparedFile(url: preparedURL, label: "DOCX export file is verified and ready.")

        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.fileExportSaved(preparedURL)) {
            $0.operationStatus = .saved("File saved to reports.docx.")
        }
        await store.send(.fileExportCancelled) {
            $0.operationStatus = .cancelled("File export cancelled. No saved-file success was recorded.")
        }
        await store.send(.fileExportFailed("Disk is full.")) {
            $0.operationStatus = .failed("File export failed: Disk is full.")
        }
        await store.send(.fileShareStarted(preparedURL)) {
            $0.operationStatus = .busy("Opening native share sheet for reports.docx.")
        }
        await store.send(.fileShareCompleted(preparedURL)) {
            $0.operationStatus = .shared("Share completed for reports.docx.")
        }
        await store.send(.fileShareCancelled) {
            $0.operationStatus = .cancelled("Share cancelled. No share success was recorded.")
        }
        await store.send(.fileShareFailed("No destination accepted the file.")) {
            $0.operationStatus = .failed("Share failed: No destination accepted the file.")
        }
    }

    func testGenerationFailureDoesNotSaveOrReportSuccess() async {
        let original = project(id: "p1", name: "Room 5", revision: 3)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.datasetStatus = .loaded(DatasetSnapshot(hash: "h", normalizedSourceHash: "n", subjectCount: 1, componentCount: 1, recipeCount: 1, assembledVariantCount: 1, uniquenessGuardCount: 0, warnings: [], summary: "ok"))
        initial.projectStorageStatus = .loaded
        initial.selectedProject = original

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { project in
                XCTAssertEqual(project, original)
                await probe.record("failed-generation")
                throw TestGenerationFailure()
            }
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { _, _, _, _ in
                    await probe.record("unexpected-save")
                    throw TestUnexpectedSave()
                }
            )
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating reports from the bundled production dataset.")
        }
        await store.receive(.reportsGenerationFailed("Generation failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("Reports were not generated: Generation failed for test.")
        }
        XCTAssertEqual(await probe.values(), ["failed-generation"])
    }
}

private struct TestSaveFailure: LocalizedError {
    var errorDescription: String? {
        "Save failed for test."
    }
}

private struct TestImportFailure: LocalizedError {
    var errorDescription: String? {
        "Import parse failed for test."
    }
}

private struct TestFilePreparationFailure: LocalizedError {
    var errorDescription: String? {
        "File preparation failed for test."
    }
}

private struct TestGenerationFailure: LocalizedError {
    var errorDescription: String? {
        "Generation failed for test."
    }
}

private struct TestUnexpectedSave: LocalizedError {
    var errorDescription: String? {
        "Unexpected save call."
    }
}

private actor WorkflowProbe {
    private var recordedValues: [String] = []

    func record(_ value: String) {
        recordedValues.append(value)
    }

    func values() -> [String] {
        recordedValues
    }
}

private func testProjectStoreClient(
    listProjects: @escaping @Sendable () async throws -> [ProjectSummary] = { [] },
    createProject: @escaping @Sendable () async throws -> ProjectSummary = {
        ProjectSummary(id: "p1", name: "Room 5", term: "Term 1", updatedAt: 1, revision: 1)
    },
    loadProject: @escaping @Sendable (_ id: String) async throws -> Project = { id in
        project(id: id)
    },
    saveProject: @escaping @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project = { project, _, _, _ in
        project
    },
    deleteProject: @escaping @Sendable (_ id: String) async throws -> [ProjectSummary] = { _ in [] },
    importRosterFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview = { _, project in
        importPreview(format: .csv, kind: .roster, count: 0, project: project)
    },
    importResultsFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview = { _, project in
        importPreview(format: .csv, kind: .results, count: 0, project: project)
    },
    importBackup: @escaping @Sendable (_ url: URL) async throws -> Project = { _ in project(id: "imported") },
    prepareBackup: @escaping @Sendable (_ project: Project) async throws -> URL = { _ in URL(fileURLWithPath: "/tmp/commenter-backup.json") },
    prepareReportExport: @escaping @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL = { _, format in
        URL(fileURLWithPath: "/tmp/commenter-report.\(format.rawValue)")
    }
) -> ProjectStoreClient {
    ProjectStoreClient(
        listProjects: listProjects,
        createProject: createProject,
        loadProject: loadProject,
        saveProject: saveProject,
        deleteProject: deleteProject,
        importRosterFile: importRosterFile,
        importResultsFile: importResultsFile,
        importBackup: importBackup,
        prepareBackup: prepareBackup,
        prepareReportExport: prepareReportExport
    )
}

private func importPreview(
    format: ImportExportFormat,
    kind: ProjectImportChangeKind,
    count: Int,
    project: Project
) -> PreparedProjectImportPreview {
    PreparedProjectImportPreview(
        sourceFormat: format,
        change: PreparedProjectImportChange(kind: kind, importedCount: count, project: project)
    )
}

private func projectSummary(_ project: Project) -> ProjectSummary {
    ProjectSummary(
        id: project.metadata.id,
        name: project.metadata.name,
        term: project.metadata.term,
        updatedAt: project.metadata.updatedAt,
        revision: project.metadata.persistence?.revision
    )
}

private func project(
    id: String = "p1",
    name: String = "Room 5",
    term: String = "Term 1",
    updatedAt: Int64 = 1,
    revision: Int? = 1
) -> Project {
    Project(
        metadata: ProjectMetadata(
            id: id,
            name: name,
            term: term,
            yearLevel: .year5,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            selectedSubjects: [:],
            useFirstNameOnly: true,
            persistence: ProjectPersistenceMetadata(revision: revision)
        )
    )
}
