@testable import AppFeature
import ComposableArchitecture
import CommenterAI
import CommentEngine
import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import Foundation
import UniformTypeIdentifiers
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
    func testBackupPickerIncludesPasswordProtectedCBackupFiles() {
        XCTAssertTrue(ImportMode.backup.allowedContentTypes.contains(.encryptedCommenterBackup))
        XCTAssertTrue(UTType.encryptedCommenterBackup.conforms(to: .json))
    }

    func testTaskLoadsDatasetAndRealProjectSummaries() async {
        let snapshot = datasetSnapshot(loadedAt: 1_000)
        let summary = ProjectSummary(id: "p1", name: "Room 5", term: "Term 1", updatedAt: 2, revision: 4)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient { snapshot }
            $0.projectStoreClient = testProjectStoreClient(listProjects: { [summary] })
        }

        await store.send(.task) {
            $0.datasetStatus = .loading
            $0.projectStorageStatus = .loading
            $0.projectStorageMessage = "Checking local project storage."
        }
        await store.receive(.datasetLoaded(snapshot)) {
            $0.datasetStatus = .loaded(snapshot)
        }
        await store.receive(.projectStoreLoaded(ProjectListDiagnostics(projects: [summary]))) {
            $0.projectStorageStatus = .loaded
            $0.projects = [summary]
            $0.projectStorageMessage = "1 saved project loaded from local storage."
        }
        await store.receive(.aiAvailabilityLoaded(.unavailable(reason: "Apple Intelligence isn't available on this iPhone."))) {
            $0.aiAvailability = .unavailable(reason: "Apple Intelligence isn't available on this iPhone.")
        }
    }

    func testTaskReportsInvalidLocalProjectRecordsWithoutBlockingValidProjects() async {
        let snapshot = datasetSnapshot(loadedAt: 1_000)
        let summary = ProjectSummary(id: "p1", name: "Room 5", term: "Term 1", updatedAt: 2, revision: 4)
        let invalid = InvalidProjectRecord(id: "broken", reason: "Stored project fingerprint verification failed.")
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient { snapshot }
            $0.projectStoreClient = testProjectStoreClient(
                listProjectDiagnostics: {
                    ProjectListDiagnostics(projects: [summary], invalidProjects: [invalid])
                }
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
        await store.receive(.projectStoreLoaded(ProjectListDiagnostics(projects: [summary], invalidProjects: [invalid]))) {
            $0.projectStorageStatus = .loaded
            $0.projects = [summary]
            $0.invalidProjectRecords = [invalid]
            $0.projectStorageMessage = "1 saved project loaded from local storage. 1 local project record could not be loaded and is listed in Support diagnostics."
        }
        await store.receive(.aiAvailabilityLoaded(.unavailable(reason: "Apple Intelligence isn't available on this iPhone."))) {
            $0.aiAvailability = .unavailable(reason: "Apple Intelligence isn't available on this iPhone.")
        }
    }

    func testTaskSurfacesStalePreparedFileCleanupFailureWithoutBlockingStorageLoad() async {
        let snapshot = datasetSnapshot(loadedAt: 1_000)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.datasetClient = DatasetClient { snapshot }
            $0.projectStoreClient = testProjectStoreClient(
                purgeStalePreparedFiles: {
                    throw ProjectStoreError.unavailable("Temporary cleanup failed.")
                }
            )
        }

        await store.send(.task) {
            $0.datasetStatus = .loading
            $0.projectStorageStatus = .loading
            $0.projectStorageMessage = "Checking local project storage."
        }
        await store.receive(.stalePreparedFilePurgeFailed("Temporary cleanup failed.")) {
            $0.operationStatus = .failed("Old temporary prepared files could not be fully removed. Current project data was not changed, and cleanup will be tried again next launch. Temporary cleanup failed.")
        }
        await store.receive(.datasetLoaded(snapshot)) {
            $0.datasetStatus = .loaded(snapshot)
        }
        await store.receive(.projectStoreLoaded(ProjectListDiagnostics(projects: []))) {
            $0.projectStorageStatus = .loaded
            $0.projectStorageMessage = "Project storage is available and ready."
        }
        await store.receive(.aiAvailabilityLoaded(.unavailable(reason: "Apple Intelligence isn't available on this iPhone."))) {
            $0.aiAvailability = .unavailable(reason: "Apple Intelligence isn't available on this iPhone.")
        }
    }

    func testDamagedRecordSupportCopyIsReportedReadyOnlyAfterVerifiedStoreCopyReturns() async {
        let recordID = "record-token"
        let url = URL(fileURLWithPath: "/tmp/Damaged-project-Support-Copy-NOT-A-BACKUP.json")
        let copy = InvalidProjectSupportCopy(
            recordID: recordID,
            fileURL: url,
            warning: "This is a raw damaged-record support copy, not a backup. It cannot be restored or imported as a Commenter backup."
        )
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 123 })
            $0.projectStoreClient = testProjectStoreClient(
                prepareInvalidProjectSupportCopy: { receivedRecordID in
                    XCTAssertEqual(receivedRecordID, recordID)
                    return copy
                }
            )
        }

        await store.send(.invalidProjectSupportCopyTapped(recordID)) {
            $0.projectStorageStatus = .preparingFile
            $0.operationStatus = .busy("Preparing an exact raw copy of the damaged saved-work record.")
        }
        await store.receive(.invalidProjectSupportCopyPrepared(copy, 123)) {
            $0.projectStorageStatus = .loaded
            $0.preparedFile = AppFeature.PreparedFile(
                url: url,
                label: copy.warning,
                purpose: .damagedRecordSupportCopy,
                preparedAtMilliseconds: 123,
                projectID: nil
            )
            $0.operationStatus = .prepared(copy.warning)
        }
    }

    func testDamagedRecordRemovalRefreshesValidAndInvalidProjectLists() async {
        let recordID = "record-token"
        let valid = ProjectSummary(id: "p1", name: "Room 5", term: "Term 1", updatedAt: 9, revision: 2)
        let refreshed = ProjectListDiagnostics(projects: [valid], invalidProjects: [])
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.invalidProjectRecords = [
            InvalidProjectRecord(id: "broken", reason: "Stored project fingerprint verification failed.", recordID: recordID)
        ]
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                removeInvalidProject: { receivedRecordID in
                    XCTAssertEqual(receivedRecordID, recordID)
                    return refreshed
                }
            )
        }

        await store.send(.invalidProjectRemovalConfirmed(recordID)) {
            $0.projectStorageStatus = .deleting
            $0.operationStatus = .busy("Removing damaged saved work from the active project list while retaining its recovery material.")
        }
        await store.receive(.invalidProjectRemoved(refreshed)) {
            $0.projectStorageStatus = .loaded
            $0.projects = [valid]
            $0.invalidProjectRecords = []
            $0.projectStorageMessage = "1 saved project loaded from local storage."
            $0.operationStatus = .saved("Damaged saved work was removed from active projects. Its local recovery material was retained in the app's quarantine area.")
        }
    }

    func testProjectCreationRequiresNamingFlowAndOpensSavedProjectOnlyAfterStoreReturns() async {
        let savedSummary = ProjectSummary(id: "saved-id", name: "Room 5", term: "Term 2", updatedAt: 10, revision: 1)
        let savedProject = project(id: savedSummary.id, name: savedSummary.name, term: savedSummary.term, updatedAt: savedSummary.updatedAt, revision: savedSummary.revision)
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projectStorageMessage = "Project storage is available and ready."

        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                createProject: { draft in
                    XCTAssertEqual(draft.normalizedName, "Room 5")
                    XCTAssertEqual(draft.normalizedTerm, "Term 2")
                    XCTAssertEqual(draft.yearLevel, .year6)
                    XCTAssertFalse(draft.useFirstNameOnly)
                    await probe.record("create")
                    return savedSummary
                },
                loadProject: { id in
                    XCTAssertEqual(id, savedSummary.id)
                    await probe.record("load")
                    return savedProject
                }
            )
        }

        await store.send(.createProjectTapped) {
            $0.projectCreationDraft = .init()
            $0.operationStatus = .idle
        }
        await store.send(.projectCreationNameChanged("Room 5")) {
            $0.projectCreationDraft?.name = "Room 5"
        }
        await store.send(.projectCreationTermChanged("Term 2")) {
            $0.projectCreationDraft?.term = "Term 2"
        }
        await store.send(.projectCreationYearLevelChanged(.year6)) {
            $0.projectCreationDraft?.yearLevel = .year6
        }
        await store.send(.projectCreationUseFirstNameOnlyChanged(false)) {
            $0.projectCreationDraft?.useFirstNameOnly = false
        }
        await store.send(.confirmCreateProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.operationStatus = .busy("Creating and verifying Room 5.")
            $0.projectStorageMessage = "Creating and verifying Room 5."
        }
        await store.receive(.projectCreateSaved(savedSummary)) {
            $0.projectCreationDraft = nil
            $0.projectStorageStatus = .loaded
            $0.projects = [savedSummary]
            $0.projectStorageMessage = "Project saved locally and verified: Room 5."
            $0.operationStatus = .saved("Project saved locally and verified: Room 5.")
        }
        await store.receive(.projectTapped(savedSummary.id)) {
            $0.projectStorageStatus = .loadingProject
            $0.operationStatus = .busy("Opening project.")
        }
        await store.receive(.projectLoaded(savedProject)) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = savedProject
            $0.selectedProjectReadiness = getProjectReadiness(savedProject)
            $0.preparedFile = nil
            $0.pendingImport = nil
            $0.workflowMessage = "Room 5 is open."
            $0.operationStatus = .saved("Project opened from verified local storage.")
            $0.selectedTab = .worklist
            $0.rosterImportState = .neverImported
            $0.resultsImportState = .neverImported
        }
        await XCTAssertProbeValues(probe, ["create", "load"])
    }

    func testProjectCreationRejectsBlankNameWithoutCallingStore() async {
        let probe = WorkflowProbe()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projectCreationDraft = .init(name: "   ")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(createProject: { _ in
                await probe.record("unexpected-create")
                throw TestUnexpectedSave()
            })
        }

        await store.send(.confirmCreateProjectTapped) {
            $0.operationStatus = .failed("Enter a class or project name before creating the project.")
        }
        await XCTAssertProbeValues(probe, [])
    }

    func testNoProjectRecoveryCanNavigateToProjectsTab() async {
        var initial = AppFeature.State()
        initial.selectedTab = .worklist
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.tabSelected(.projects)) {
            $0.selectedTab = .projects
        }
    }

    func testAppIntentRoutesOpenThePromisedWorklistDestination() async {
        var initial = loadedState(project: readyProject())
        initial.selectedTab = .projects
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.appIntentRouteReceived(.reportPreparation)) {
            $0.selectedTab = .worklist
            $0.worklistFocus = .files
            $0.operationStatus = .prepared("Report preparation opened. All 1 reports are ready for file preparation.")
        }
    }

    func testDirtyProjectBlocksCreationAndRosterImportWithoutStartingStorageWork() async {
        let probe = WorkflowProbe()
        var initial = loadedState(project: project(subjects: ["English"], roster: [student()]))
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importRosterFile: { _, _ in
                await probe.record("unexpected-import")
                throw TestImportFailure()
            })
        }

        await store.send(.createProjectTapped) {
            $0.operationStatus = .failed("Save the open project before creating another project so no teacher edits are stranded.")
        }
        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.csv"))) {
            $0.operationStatus = .failed("Save the open project before starting roster import so the operation uses verified local state and does not silently include other unsaved edits.")
        }
        await XCTAssertProbeValues(probe, [])
    }

    func testRosterAddEditDeleteMarksProjectDirtyAndKeepsVisibleState() async {
        var initial = loadedState(project: project(subjects: ["English"]))
        initial.preparedFile = AppFeature.PreparedFile(
            url: URL(fileURLWithPath: "/tmp/old.docx"),
            label: "Previously prepared report file",
            projectID: "p1"
        )
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.addStudentTapped) {
            $0.selectedProject?.roster = [Student(id: "student-1", firstName: "", lastName: "", yearLevel: .year5)]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.preparedFile?.isStale = true
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentFirstNameChanged("student-1", "Ava")) {
            $0.selectedProject?.roster[0].firstName = "Ava"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentLastNameChanged("student-1", "Ng")) {
            $0.selectedProject?.roster[0].lastName = "Ng"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.deleteStudentTapped("student-1")) {
            $0.selectedProject?.roster = []
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testRosterCommentContextFieldsPersistAsDirtyModelState() async {
        var initial = loadedState(project: project(subjects: ["English"], roster: [student()]))
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.studentGenderChanged("s1", .female)) {
            $0.selectedProject?.roster[0].gender = .female
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentPronounsChanged("s1", "she/her")) {
            $0.selectedProject?.roster[0].pronouns = "she/her"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentInternalNoteChanged("s1", "Keep seating note private")) {
            $0.selectedProject?.roster[0].internalTeacherNote = "Keep seating note private"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentAttitudeDescriptorChanged("s1", "thoughtful")) {
            $0.selectedProject?.roster[0].attitudeDescriptor = "thoughtful"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.studentPronounsChanged("s1", "  ")) {
            $0.selectedProject?.roster[0].pronouns = nil
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testResultCommentContextFieldsPersistAsDirtyModelState() async {
        let original = project(
            subjects: ["English"],
            roster: [student()],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")]
        )
        var initial = loadedState(project: original)
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.resultEvidenceChanged("s1", "English", "uses quotations accurately")) {
            $0.selectedProject?.results[0].evidenceText = "uses quotations accurately"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultTextTypeChanged("s1", "English", "persuasive paragraph")) {
            $0.selectedProject?.results[0].textType = "persuasive paragraph"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultLearningContextChanged("s1", "English", "class novel discussion")) {
            $0.selectedProject?.results[0].learningContext = "class novel discussion"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultReportEmphasisNoteChanged("s1", "English", "They use feedback and explain clearly")) {
            $0.selectedProject?.results[0].reportEmphasisNote = "They use feedback and explain clearly"
            $0.selectedProject?.results[0].commentsText = nil
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultEnglishFocusTagsChanged("s1", "English", ["Inferencing", "Vocabulary"])) {
            $0.selectedProject?.results[0].englishFocusTags = ["Inferencing", "Vocabulary"]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultNextStepGoalsChanged("s1", "English", ["use evidence from text"])) {
            $0.selectedProject?.results[0].nextStepGoals = ["use evidence from text"]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultFlagChanged("s1", "English", "PARTICIPATION_ENGAGEMENT", true)) {
            $0.selectedProject?.results[0].flags = ["PARTICIPATION_ENGAGEMENT": true]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.resultFlagChanged("s1", "English", "PARTICIPATION_ENGAGEMENT", false)) {
            $0.selectedProject?.results[0].flags = nil
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testRosterImportPreviewCommitAndCancellationStatesAreDistinct() async {
        let original = project(subjects: ["English"])
        let imported = project(subjects: ["English"], roster: [student()])
        let preview = importPreview(format: .csv, kind: .roster, count: 1, project: imported)
        var initial = loadedState(project: original)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, reason in
                    XCTAssertEqual(project, imported)
                    XCTAssertEqual(expectedRevision, original.metadata.persistence?.revision)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(reason, .beforeSave)
                    return imported
                },
                importRosterFile: { _, project in
                    XCTAssertEqual(project, original)
                    return preview
                }
            )
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.csv"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .roster
            $0.rosterImportState = .validating("Validating roster import before changing the project.")
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        let pending = AppFeature.PendingImport(
            project: imported,
            title: "Review roster import",
            detail: "1 student validated from CSV. Confirm to save this roster import locally.",
            successMessage: "Roster imported, saved, and verified.",
            expectedRevision: original.metadata.persistence?.revision,
            recoveryReason: .beforeSave,
            kind: .roster,
            acceptedRows: 1,
            sourceFormat: .csv
        )
        await store.receive(.importPreviewPrepared(pending)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = pending
            $0.selectedTab = .worklist
            $0.activeImportKind = nil
            $0.rosterImportState = .previewReady(count: 1, source: "CSV")
            $0.operationStatus = .prepared(pending.detail)
            $0.workflowMessage = pending.detail
        }
        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .roster
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importCommitted(imported, "Roster imported, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = imported
            $0.selectedProjectReadiness = getProjectReadiness(imported)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("Roster imported, saved, and verified.")
            $0.workflowMessage = "Roster imported, saved, and verified."
            $0.projects = [projectSummary(imported)]
            $0.activeImportKind = nil
            $0.rosterImportState = .success(count: 1, source: "CSV")
        }
    }

    func testSubjectSelectAllAndDeselectAllClearDependentData() async {
        let report = GeneratedReport(studentId: "s1", subject: "English", text: "Draft", generatedAt: 1)
        let original = project(
            subjects: ["English"],
            roster: [student()],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)],
            reports: [report]
        )
        var initial = loadedState(project: original)
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.subjectSelectAllTapped) { state in
            teacherSubjectKeysInCurriculumOrder().forEach { subject in
                state.selectedProject?.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
            }
            state.selectedProjectReadiness = getProjectReadiness(state.selectedProject!)
            state.hasUnsavedProjectChanges = true
            state.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.subjectDeselectAllTapped) {
            $0.selectedProject?.metadata.selectedSubjects = [:]
            $0.selectedProject?.results = []
            $0.selectedProject?.reports = []
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testResultsImportPrerequisitesNeverStartParserWhenRosterOrSubjectsMissing() async {
        let probe = WorkflowProbe()
        var initial = loadedState(project: project())
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importResultsFile: { _, _ in
                await probe.record("unexpected-parse")
                throw TestImportFailure()
            })
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.csv"))) {
            $0.resultsImportState = .failed("Add at least one student before importing results. Select at least one subject before importing results.")
            $0.operationStatus = .failed("Results import is unavailable: Add at least one student before importing results. Select at least one subject before importing results.")
        }
        await XCTAssertProbeValues(probe, [])
    }

    func testResultsImportZeroValidRowsAndFailedStatesAreDistinct() async {
        var initial = loadedState(project: project(subjects: ["English"], roster: [student()]))
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importResultsFile: { _, _ in
                throw ImportPreviewPreparationError.noAcceptedRows("result")
            })
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.xlsx"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .results
            $0.resultsImportState = .validating("Validating results import before changing the project.")
            $0.operationStatus = .busy("Validating results import before changing the project.")
        }
        await store.receive(.importFailed("No result rows were accepted for import. Existing project data was left unchanged.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.resultsImportState = .zeroValidRecords("No result rows were accepted for import. Existing project data was left unchanged.")
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: No result rows were accepted for import. Existing project data was left unchanged.")
        }
    }

    func testGenerationPrerequisitesDuplicateTapPreventionAndFailureCopyAreTruthful() async {
        var initial = loadedState(project: project(subjects: ["English"], roster: [student()]))
        initial.datasetStatus = .loaded(datasetSnapshot())
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.generateReportsTapped) {
            $0.operationStatus = .failed("Draft comments cannot be generated yet: Complete achievement results for 1 student-subject entry.")
        }

        var busy = initial
        busy.projectStorageStatus = .generating
        let busyStore = TestStore(initialState: busy) { AppFeature() }
        await busyStore.send(.generateReportsTapped) {
            $0.operationStatus = .failed("Wait for the current local operation to finish before generating draft comments.")
        }
    }

    func testGenerationSuccessSavesAfterDeterministicEngineResultAndMarksStaleImports() async {
        let original = project(subjects: ["English"], roster: [student()], results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")])
        let generated = {
            var project = original
            project.reports = [readyReport(project: original, result: original.results[0], text: "Ava is reading well.")]
            return project
        }()
        var initial = loadedState(project: original)
        initial.datasetStatus = .loaded(datasetSnapshot())
        initial.resultsImportState = .success(count: 1, source: "CSV")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { project in
                XCTAssertEqual(project, original)
                return CommentGenerationResult(project: generated, generatedCount: 1, skippedLockedCount: 0)
            }
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, _, _, _ in
                XCTAssertEqual(project, generated)
                return generated
            })
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating deterministic draft comments from the bundled production dataset.")
        }
        await store.receive(.reportsGeneratedAndSaved(generated, "1 draft comment generated deterministically, saved, and verified. Read each new draft and mark it Done before export.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = generated
            $0.selectedProjectReadiness = getProjectReadiness(generated)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("1 draft comment generated deterministically, saved, and verified. Read each new draft and mark it Done before export.")
            $0.workflowMessage = "1 draft comment generated deterministically, saved, and verified. Read each new draft and mark it Done before export."
            $0.projects = [projectSummary(generated)]
        }
    }

    func testReportExportReadinessByFormatAndPreparedTimestamp() async {
        let ready = readyProject()
        let url = URL(fileURLWithPath: "/tmp/Room5.docx")
        var initial = loadedState(project: ready)
        initial.selectedProjectReadiness = getProjectReadiness(ready)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 123_456 })
            $0.projectStoreClient = testProjectStoreClient(prepareReportExport: { project, format in
                XCTAssertEqual(project, ready)
                XCTAssertEqual(format, .docx)
                return url
            })
        }

        await store.send(.prepareReportExportTapped(.docx)) {
            $0.projectStorageStatus = .preparingFile
            $0.preparedFile = nil
            $0.operationStatus = .busy("Checking readiness and preparing DOCX export.")
        }
        await store.receive(.filePrepared(url, "DOCX export file is verified and ready.", .docx, 123_456)) {
            $0.projectStorageStatus = .loaded
            $0.preparedFile = AppFeature.PreparedFile(url: url, label: "DOCX export file is verified and ready.", format: .docx, preparedAtMilliseconds: 123_456, projectID: "p1")
            $0.lastPreparedFiles[.docx] = AppFeature.PreparedFileRecord(format: .docx, filename: "Room5.docx", label: "DOCX export file is verified and ready.", preparedAtMilliseconds: 123_456)
            $0.operationStatus = .prepared("DOCX export file is verified and ready.")
        }
    }

    func testPasswordProtectedBackupKeepsPasswordPromptOpenForInvalidConfirmation() async {
        var initial = loadedState(project: project())
        initial.operationStatus = .saved("Project opened from verified local storage.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.prepareEncryptedBackupTapped) {
            $0.isEncryptedBackupPreparationPresented = true
            $0.operationStatus = .idle
        }
        await store.send(.prepareEncryptedBackupConfirmed("correct horse battery", "different password")) {
            $0.encryptedBackupPreparationErrorMessage = "The backup passwords do not match."
        }
    }

    func testImportTemplateIsPreparedAsAStandaloneVerifiedFile() async {
        let url = URL(fileURLWithPath: "/tmp/report_writer_class_list_template.xlsx")
        let store = TestStore(initialState: loadedState(project: project())) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 234_567 })
            $0.projectStoreClient = testProjectStoreClient(
                prepareImportTemplate: { kind, format in
                    XCTAssertEqual(kind, .roster)
                    XCTAssertEqual(format, .xlsx)
                    return url
                }
            )
        }

        await store.send(.prepareImportTemplateTapped(.roster, .xlsx)) {
            $0.projectStorageStatus = .preparingFile
            $0.operationStatus = .busy("Preparing and verifying XLSX roster import template.")
        }
        let label = "Verified XLSX roster import template is ready to save or share."
        await store.receive(.importTemplatePrepared(url, label, .xlsx, 234_567)) {
            $0.projectStorageStatus = .loaded
            $0.worklistFocus = .files
            $0.preparedFile = AppFeature.PreparedFile(
                url: url,
                label: label,
                purpose: .importTemplate,
                format: .xlsx,
                preparedAtMilliseconds: 234_567,
                projectID: nil
            )
            $0.operationStatus = .prepared(label)
        }
    }

    func testPasswordProtectedBackupReportsPreparedOnlyAfterVerifiedFileReturns() async {
        let openProject = project()
        let password = "correct horse battery"
        let url = URL(fileURLWithPath: "/tmp/Room_5_Backup_Copy.cbackup")
        var initial = loadedState(project: openProject)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 456_789 })
            $0.projectStoreClient = testProjectStoreClient(
                prepareEncryptedBackup: { receivedProject, receivedPassword in
                    XCTAssertEqual(receivedProject, openProject)
                    XCTAssertEqual(receivedPassword, password)
                    return url
                }
            )
        }

        await store.send(.prepareEncryptedBackupTapped) {
            $0.isEncryptedBackupPreparationPresented = true
            $0.operationStatus = .idle
        }
        await store.send(.prepareEncryptedBackupConfirmed(password, password)) {
            $0.isEncryptedBackupPreparationPresented = false
            $0.projectStorageStatus = .preparingFile
            $0.operationStatus = .busy("Encrypting, writing, and verifying a password-protected backup.")
        }
        let label = "Verified password-protected .cbackup file is ready. Keep its password separately; Report Writer cannot recover a forgotten password."
        await store.receive(.filePrepared(url, label, .backupJSON, 456_789)) {
            $0.projectStorageStatus = .loaded
            $0.preparedFile = AppFeature.PreparedFile(
                url: url,
                label: label,
                format: .backupJSON,
                preparedAtMilliseconds: 456_789,
                projectID: "p1"
            )
            $0.lastPreparedFiles[.backupJSON] = AppFeature.PreparedFileRecord(
                format: .backupJSON,
                filename: "Room_5_Backup_Copy.cbackup",
                label: label,
                preparedAtMilliseconds: 456_789
            )
            $0.operationStatus = .prepared(label)
        }
    }

    func testReportExportAndBackupAreBlockedForDirtyOrUnreadyState() async {
        var initial = loadedState(project: project(subjects: ["English"], roster: [student()]))
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.prepareBackupTapped) {
            $0.operationStatus = .failed("Save current changes before preparing Backup JSON so the backup reflects verified local storage.")
        }
        await store.send(.prepareReportExportTapped(.xlsx)) {
            $0.operationStatus = .failed("Save current changes before preparing report exports so files reflect verified local storage.")
        }
    }

    func testSaveSuccessUpdatesLastSavedProjectState() async {
        let original = project(subjects: ["English"], roster: [student()])
        let saved = {
            var project = original
            project.metadata.persistence = ProjectPersistenceMetadata(revision: 2, savedAt: 999, savedBy: "local-ios", fingerprint: "abc")
            return project
        }()
        var initial = loadedState(project: original)
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, expectedRevision, createRecoverySnapshot, reason in
                XCTAssertEqual(project, original)
                XCTAssertEqual(expectedRevision, original.metadata.persistence?.revision)
                XCTAssertTrue(createRecoverySnapshot)
                XCTAssertEqual(reason, .beforeSave)
                return saved
            })
        }

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
            $0.hasUnsavedProjectChanges = false
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
    }


    func testDismissStatusDoesNotClearDirtySaveGate() async {
        var initial = loadedState(project: project(subjects: ["English"]))
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.operationStatusDismissed)
    }


    func testDirtyProjectBlocksOpeningAnotherProject() async {
        var initial = loadedState(project: project(id: "p1", subjects: ["English"]))
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.projectTapped("p2")) {
            $0.operationStatus = .failed("Save the current project before opening another project so no teacher edits are discarded.")
        }
    }

    func testProjectOpenLabelsPersistedRosterAndResultsAsLoadedNotImported() async {
        let opened = readyProject()
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(loadProject: { id in
                XCTAssertEqual(id, "p1")
                return opened
            })
        }

        await store.send(.projectTapped("p1")) {
            $0.projectStorageStatus = .loadingProject
            $0.operationStatus = .busy("Opening project.")
        }
        await store.receive(.projectLoaded(opened)) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = opened
            $0.selectedProjectReadiness = getProjectReadiness(opened)
            $0.preparedFile = nil
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.workflowMessage = "Room 5 is open."
            $0.operationStatus = .saved("Project opened from verified local storage.")
            $0.selectedTab = .worklist
            $0.rosterImportState = .loaded(count: opened.roster.count, source: "verified local project")
            $0.resultsImportState = .loaded(count: opened.results.count, source: "verified local project")
        }
    }

    func testProjectListDeletionUsesRecoveryPathAndSelectedProjectDeletionClearsState() async {
        let open = project(id: "p1", name: "Room 5", subjects: ["English"])
        let other = ProjectSummary(id: "p2", name: "Room 6", term: "Term 2", updatedAt: 20, revision: 2)
        var initial = loadedState(project: open)
        initial.projects = [projectSummary(open), other]
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(deleteProject: { id in
                XCTAssertEqual(id, "p1")
                return [other]
            })
        }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.projectStorageStatus = .deleting
            $0.preparedFile = nil
            $0.pendingImport = nil
            $0.activeImportKind = nil
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
            $0.preparedFile = nil
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.operationStatus = .saved("Room 5 was deleted after a verified recovery snapshot was created.")
        }
    }

    func testShareCancellationAndExportCancellationNeverReportSuccess() async {
        let preparedURL = URL(fileURLWithPath: "/tmp/reports.docx")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.preparedFile = AppFeature.PreparedFile(url: preparedURL, label: "DOCX export file is verified and ready.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.fileExportCancelled) {
            $0.operationStatus = .busy("File export cancelled. Removing temporary prepared copy.")
        }
        await store.receive(.preparedFileDiscardCompleted(.cancelled("File export cancelled. Temporary prepared copy was removed."))) {
            $0.preparedFile = nil
            $0.operationStatus = .cancelled("File export cancelled. Temporary prepared copy was removed.")
        }

        initial.preparedFile = AppFeature.PreparedFile(url: preparedURL, label: "DOCX export file is verified and ready.")
        let shareStore = TestStore(initialState: initial) { AppFeature() }
        await shareStore.send(.fileShareCancelled) {
            $0.operationStatus = .busy("Share cancelled. Removing temporary prepared copy.")
        }
        await shareStore.receive(.preparedFileDiscardCompleted(.cancelled("Share cancelled. Temporary prepared copy was removed."))) {
            $0.preparedFile = nil
            $0.operationStatus = .cancelled("Share cancelled. Temporary prepared copy was removed.")
        }

        initial.preparedFile = AppFeature.PreparedFile(url: preparedURL, label: "DOCX export file is verified and ready.")
        let completedStore = TestStore(initialState: initial) { AppFeature() }
        await completedStore.send(.fileShareCompleted(preparedURL)) {
            $0.operationStatus = .busy("Share completed for reports.docx. Removing temporary prepared copy.")
        }
        await completedStore.receive(.preparedFileDiscardCompleted(.shared("Share completed for reports.docx. Temporary prepared copy was removed."))) {
            $0.preparedFile = nil
            $0.operationStatus = .shared("Share completed for reports.docx. Temporary prepared copy was removed.")
        }
    }

    func testPreparedFileDiscardFailureShowsCleanupWarning() async {
        let preparedURL = URL(fileURLWithPath: "/tmp/reports.docx")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.preparedFile = AppFeature.PreparedFile(url: preparedURL, label: "DOCX export file is verified and ready.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(discardPreparedFile: { _ in
                throw TestPreparedFileDiscardFailure()
            })
        }

        await store.send(.fileExportSaved(URL(fileURLWithPath: "/tmp/saved/reports.docx"))) {
            $0.operationStatus = .busy("File saved to reports.docx. Removing temporary prepared copy.")
        }
        await store.receive(.preparedFileDiscardFailed("File saved to reports.docx, but the temporary prepared copy could not be removed: Prepared file discard failed for test.")) {
            $0.operationStatus = .failed("File saved to reports.docx, but the temporary prepared copy could not be removed: Prepared file discard failed for test.")
        }
    }

    func testCopyDiagnosticsContentAndClipboardEffect() async {
        let snapshot = datasetSnapshot(hash: "abc", normalized: "abc", loadedAt: 1_000)
        var initial = loadedState(project: readyProject())
        initial.datasetStatus = .loaded(snapshot)
        initial.lastPreparedFiles[.backupJSON] = AppFeature.PreparedFileRecord(format: .backupJSON, filename: "backup.json", label: "Ready", preparedAtMilliseconds: 2_000)
        let probe = WorkflowProbe()
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.clipboardClient = ClipboardClient(copy: { text in
                XCTAssertTrue(text.contains("Report Writer Support Diagnostics"))
                XCTAssertTrue(text.contains("Hash verification: verified match"))
                XCTAssertTrue(text.contains("Prepared files:"))
                XCTAssertTrue(text.contains("Privacy:"))
                await probe.record("copied")
            })
        }

        await store.send(.copyDiagnosticsTapped) {
            $0.operationStatus = .busy("Copying support diagnostics.")
        }
        await store.receive(.copyDiagnosticsSucceeded) {
            $0.operationStatus = .saved("Diagnostics copied to clipboard.")
        }
        await XCTAssertProbeValues(probe, ["copied"])
    }

    func testSupportFormattingHelpersAreLocaleAwareAndAccessible() {
        XCTAssertEqual(CommenterFormatters.integer(56_564, locale: Locale(identifier: "en_US")), "56,564")
        XCTAssertEqual(CommenterFormatters.timestamp(nil, locale: Locale(identifier: "en_US"), timeZone: TimeZone(secondsFromGMT: 0)!), "Not yet recorded")
        XCTAssertEqual(displaySubjectName("Health and P.E."), "Health and Physical Education")
        XCTAssertEqual(australianCurriculumSubjectOrder.map(\.key), teacherSubjectKeysInCurriculumOrder())
        XCTAssertEqual(
            selectedSubjectKeys([
                "Technologies": SelectedSubject(name: "Technologies", allStrandsSelected: true),
                "English": SelectedSubject(name: "English", allStrandsSelected: true),
                "Mathematics": SelectedSubject(name: "Mathematics", allStrandsSelected: true)
            ]),
            ["English", "Mathematics", "Technologies"]
        )

        var state = loadedState(project: readyProject())
        state.datasetStatus = .loaded(datasetSnapshot(hash: "hash", normalized: "hash", loadedAt: 1_000))
        state.invalidProjectRecords = [
            InvalidProjectRecord(id: "broken", reason: "Stored project fingerprint verification failed.")
        ]
        let text = supportDiagnosticsText(
            state: state,
            buildInfo: AppBuildInfo(displayName: "Report Writer", version: "1.0", build: "42"),
            locale: Locale(identifier: "en_US"),
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        XCTAssertTrue(text.contains("App version: 1.0"))
        XCTAssertTrue(text.contains("Build: 42"))
        XCTAssertTrue(text.contains("Components: 56,564"))
        XCTAssertTrue(text.contains("Hash verification: verified match"))
        XCTAssertTrue(text.contains("Invalid local project records:"))
        XCTAssertTrue(text.contains("Stored project fingerprint verification failed."))
        XCTAssertFalse(text.contains("broken: Stored project fingerprint verification failed."))
        XCTAssertFalse(text.contains("Ava"))
        XCTAssertFalse(text.contains("Project id: p1"))
        XCTAssertTrue(text.contains("Redaction: student and project identifiers redacted"))
        XCTAssertTrue(text.contains("Backup guidance:"))
    }

    func testUserVisibleErrorMessagesRedactLocalPaths() {
        XCTAssertEqual(
            sanitizedUserVisibleMessage("Could not open C:\\Users\\Teacher\\Room5\\project.json"),
            "Could not open [local file]"
        )
        XCTAssertEqual(
            sanitizedUserVisibleMessage("Could not write /private/var/mobile/project.json."),
            "Could not write [local file]."
        )
    }

    func testCreateProjectOnlyReportsSuccessAfterStoreReturnsSavedProject() async {
        await testProjectCreationRequiresNamingFlowAndOpensSavedProjectOnlyAfterStoreReturns()
    }

    func testCreateProjectFailureDoesNotAppendAProject() async {
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projectCreationDraft = .init(name: "Room 5")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(createProject: { _ in
                throw TestSaveFailure()
            })
        }

        await store.send(.confirmCreateProjectTapped) {
            $0.projectStorageStatus = .creating
            $0.operationStatus = .busy("Creating and verifying Room 5.")
            $0.projectStorageMessage = "Creating and verifying Room 5."
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
            $0.projectStoreClient = testProjectStoreClient(createProject: { _ in
                await probe.record("unexpected-create")
                throw TestUnexpectedSave()
            })
        }

        await store.send(.createProjectTapped) {
            $0.operationStatus = .failed("Project storage is not available yet. Wait for local storage to load, or resolve the storage error shown on this screen.")
        }
        await XCTAssertProbeValues(probe, [])
    }

    func testDeleteProjectCreatesRecoverySnapshotThenClearsOpenProject() async {
        await testProjectListDeletionUsesRecoveryPathAndSelectedProjectDeletionClearsState()
    }

    func testDirtyProjectCannotBeDeletedUntilVerifiedStorageReflectsCurrentState() async {
        var initial = loadedState(project: project(id: "p1", name: "Room 5", subjects: ["English"]))
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.operationStatus = .failed("Save or reopen the project before deleting it so the recovery snapshot reflects verified local storage.")
        }
    }

    func testPendingImportBlocksProjectDeletion() async {
        let original = project(id: "p1", name: "Room 5", subjects: ["English"])
        var imported = original
        imported.roster = [student()]
        var initial = loadedState(project: original)
        initial.pendingImport = AppFeature.PendingImport(
            project: imported,
            title: "Review roster import",
            detail: "1 student validated from CSV.",
            successMessage: "Roster imported, saved, and verified.",
            expectedRevision: original.metadata.persistence?.revision,
            recoveryReason: .beforeSave,
            kind: .roster,
            acceptedRows: 1,
            sourceFormat: .csv
        )
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.deleteProjectConfirmed("p1")) {
            $0.operationStatus = .failed("Review roster import is waiting. Confirm or cancel the import before deleting this project.")
        }
    }

    func testProjectYearLevelEditMarksProjectDirtyAndSaveUsesVerifiedStorePath() async {
        let original = project(subjects: ["English"])
        let edited = {
            var project = original
            project.metadata.yearLevel = .year6
            return project
        }()
        let saved = {
            var project = edited
            project.metadata.persistence = ProjectPersistenceMetadata(revision: 2, savedAt: 2_000, savedBy: "local-ios", fingerprint: "saved")
            return project
        }()
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, expectedRevision, createRecoverySnapshot, reason in
                XCTAssertEqual(project.metadata.yearLevel, .year6)
                XCTAssertEqual(expectedRevision, original.metadata.persistence?.revision)
                XCTAssertTrue(createRecoverySnapshot)
                XCTAssertEqual(reason, .beforeSave)
                return saved
            })
        }

        await store.send(.projectYearLevelChanged(.year6)) {
            $0.selectedProject?.metadata.yearLevel = .year6
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
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
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.hasUnsavedProjectChanges = false
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
    }

    func testManualMetadataEditsStayDirtyUntilVerifiedSaveReturns() async {
        let original = project(subjects: ["English"])
        let saved = {
            var project = original
            project.metadata.name = "Room 6"
            project.metadata.term = "Term 3"
            project.metadata.useFirstNameOnly = false
            project.metadata.persistence = ProjectPersistenceMetadata(revision: 2, savedAt: 3_000, savedBy: "local-ios", fingerprint: "saved")
            return project
        }()
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, _, _, _ in
                XCTAssertEqual(project.metadata.name, "Room 6")
                XCTAssertEqual(project.metadata.term, "Term 3")
                XCTAssertFalse(project.metadata.useFirstNameOnly)
                return saved
            })
        }

        await store.send(.projectNameChanged("Room 6")) {
            $0.selectedProject?.metadata.name = "Room 6"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.projectTermChanged("Term 3")) {
            $0.selectedProject?.metadata.term = "Term 3"
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.useFirstNameOnlyChanged(false)) {
            $0.selectedProject?.metadata.useFirstNameOnly = false
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
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
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.hasUnsavedProjectChanges = false
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(saved)]
        }
    }

    func testManualRosterSubjectResultAndReportEditsAreSavedOnlyThroughStoreResponse() async {
        let original = readyProject()
        let edited = {
            var project = original
            project.reports[0].manualEdit = "Teacher reviewed draft."
            project.reports[0].isLocked = true
            return project
        }()
        var initial = loadedState(project: original)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, _, _, _ in
                XCTAssertEqual(project.reports[0].manualEdit, "Teacher reviewed draft.")
                XCTAssertTrue(project.reports[0].isLocked)
                return edited
            })
        }

        await store.send(.reportManualEditChanged("s1", "English", "Teacher reviewed draft.")) {
            $0.selectedProject?.reports[0].manualEdit = "Teacher reviewed draft."
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.reportLockChanged("s1", "English", true)) {
            $0.selectedProject?.reports[0].isLocked = true
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
        await store.send(.saveProjectTapped) {
            $0.projectStorageStatus = .saving
            $0.operationStatus = .busy("Saving and verifying project.")
        }
        await store.receive(.projectSaved(edited, "Project saved locally and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = edited
            $0.selectedProjectReadiness = getProjectReadiness(edited)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.hasUnsavedProjectChanges = false
            $0.operationStatus = .saved("Project saved locally and verified.")
            $0.workflowMessage = "Project saved locally and verified."
            $0.projects = [projectSummary(edited)]
        }
    }

    func testDeterministicDraftMustBeMarkedDoneAndCurrentWordingEditInvalidatesDone() async {
        var draftProject = readyProject()
        draftProject.reports[0].invalidateTeacherReview()
        var initial = loadedState(project: draftProject)
        initial.selectedProjectReadiness = getProjectReadiness(draftProject)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportMarkedDone("s1", "English")) {
            $0.selectedProject?.reports[0].markTeacherReviewed(at: 10_000)
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Draft marked Done. Save the project to persist its teacher-review status and include it in export.")
        }
        await store.send(.reportManualEditChanged("s1", "English", "Ava reads thoughtfully and with confidence.")) {
            $0.selectedProject?.reports[0].applyManualEdit("Ava reads thoughtfully and with confidence.")
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testManualEditSaveFailureDoesNotReportSuccessOrReplaceDirtyProject() async {
        let original = project(subjects: ["English"])
        var initial = loadedState(project: original)
        initial.hasUnsavedProjectChanges = true
        initial.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { _, _, _, _ in
                throw TestSaveFailure()
            })
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
        await testRosterImportPreviewCommitAndCancellationStatesAreDistinct()
    }

    func testRosterImportFailureLeavesSelectedProjectUnchanged() async {
        let original = project(subjects: ["English"])
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importRosterFile: { _, _ in
                throw TestImportFailure()
            })
        }

        await store.send(.rosterImportPicked(URL(fileURLWithPath: "/tmp/roster.csv"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .roster
            $0.rosterImportState = .validating("Validating roster import before changing the project.")
            $0.operationStatus = .busy("Validating roster import before changing the project.")
        }
        await store.receive(.importFailed("Import parse failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.rosterImportState = .failed("Import parse failed for test.")
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: Import parse failed for test.")
        }
    }

    func testGenerationReportsSuccessOnlyAfterGenerationAndVerifiedSave() async {
        await testGenerationSuccessSavesAfterDeterministicEngineResultAndMarksStaleImports()
    }

    func testGenerationSuccessMessageReportsLockedSkipsTruthfully() async {
        let original = project(subjects: ["English"], roster: [student()], results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")])
        let generated = {
            var project = original
            project.reports = [readyReport(project: original, result: original.results[0], text: "Ava is reading well.")]
            return project
        }()
        var initial = loadedState(project: original)
        initial.datasetStatus = .loaded(datasetSnapshot())
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { _ in
                CommentGenerationResult(project: generated, generatedCount: 1, skippedLockedCount: 1)
            }
            $0.projectStoreClient = testProjectStoreClient(saveProject: { project, _, _, _ in project })
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating deterministic draft comments from the bundled production dataset.")
        }
        await store.receive(.reportsGeneratedAndSaved(generated, "1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified. Read each new draft and mark it Done before export.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = generated
            $0.selectedProjectReadiness = getProjectReadiness(generated)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified. Read each new draft and mark it Done before export.")
            $0.workflowMessage = "1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified. Read each new draft and mark it Done before export."
            $0.projects = [projectSummary(generated)]
        }
    }

    func testPrepareReportExportOnlyReportsPreparedAfterClientReturnsURL() async {
        await testReportExportReadinessByFormatAndPreparedTimestamp()
    }

    func testBackupImportPickPreparesPreviewWithoutSavingThenConfirmCommits() async {
        let imported = project(id: "imported", name: "Imported Room", subjects: ["English"], roster: [student()])
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, reason in
                    XCTAssertEqual(project, imported)
                    XCTAssertNil(expectedRevision)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(reason, .beforeImportReplace)
                    return imported
                },
                importBackup: { _, _ in imported }
            )
        }

        await store.send(.backupImportPicked(URL(fileURLWithPath: "/tmp/backup.json"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Validating backup JSON before saving it locally.")
        }
        let pending = AppFeature.PendingImport(
            project: imported,
            title: "Review backup import",
            detail: "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
            successMessage: "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
            expectedRevision: nil,
            recoveryReason: .beforeImportReplace,
            kind: .backup,
            acceptedRows: 1,
            sourceFormat: .backupJSON
        )
        await store.receive(.importPreviewPrepared(pending)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = pending
            $0.selectedTab = .worklist
            $0.activeImportKind = nil
            $0.operationStatus = .prepared(pending.detail)
            $0.workflowMessage = pending.detail
        }
        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importCommitted(imported, pending.successMessage)) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = imported
            $0.selectedProjectReadiness = getProjectReadiness(imported)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.activeImportKind = nil
            $0.operationStatus = .saved(pending.successMessage)
            $0.workflowMessage = pending.successMessage
            $0.projects = [projectSummary(imported)]
        }
    }

    func testEncryptedBackupWrongPasswordKeepsTheChosenFileForRetry() async {
        let url = URL(fileURLWithPath: "/tmp/encrypted.report-writer-backup.json")
        var initial = loadedState(project: readyProject())
        initial.pendingEncryptedBackupURL = url
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importBackup: { _, _ in
                throw BackupError.encryptedCouldNotDecrypt
            })
        }

        await store.send(.backupPasswordEntered(url, "wrong password")) {
            $0.pendingEncryptedBackupURL = nil
            $0.encryptedBackupErrorMessage = nil
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Decrypting and validating encrypted backup before saving locally.")
        }
        let message = "The encrypted backup could not be opened. Check the password and try again; no project data changed."
        await store.receive(.encryptedBackupPasswordRejected(url, message)) {
            $0.projectStorageStatus = .loaded
            $0.activeImportKind = nil
            $0.pendingEncryptedBackupURL = url
            $0.encryptedBackupErrorMessage = message
            $0.operationStatus = .failed(message)
        }
    }

    func testBackupImportReplaceFailsWhenExistingProjectRevisionChangesAfterPreview() async {
        let existingSummary = ProjectSummary(id: "p1", name: "Room 5", term: "Term 1", updatedAt: 1, revision: 4)
        let imported = project(id: "p1", name: "Imported Room", subjects: ["English"], roster: [student()])
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.projects = [existingSummary]
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, expectedRevision, createRecoverySnapshot, reason in
                    XCTAssertEqual(project, imported)
                    XCTAssertEqual(expectedRevision, 4)
                    XCTAssertTrue(createRecoverySnapshot)
                    XCTAssertEqual(reason, .beforeImportReplace)
                    throw ProjectStoreError.revisionConflict
                },
                importBackup: { _, _ in imported }
            )
        }

        await store.send(.backupImportPicked(URL(fileURLWithPath: "/tmp/backup.json"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Validating backup JSON before saving it locally.")
        }
        let rawPending = AppFeature.PendingImport(
            project: imported,
            title: "Review backup import",
            detail: "Imported Room was validated from backup JSON. Confirm to save it locally; any matching project id will be snapshotted before replacement.",
            successMessage: "Backup imported, saved, and verified. A matching local project id was replaced only after a recovery snapshot was prepared.",
            expectedRevision: nil,
            recoveryReason: .beforeImportReplace,
            kind: .backup,
            acceptedRows: 1,
            sourceFormat: .backupJSON
        )
        var revisionBoundPending = rawPending
        revisionBoundPending.expectedRevision = 4
        await store.receive(.importPreviewPrepared(rawPending)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = revisionBoundPending
            $0.selectedTab = .worklist
            $0.activeImportKind = nil
            $0.operationStatus = .prepared(rawPending.detail)
            $0.workflowMessage = rawPending.detail
        }
        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importFailed(ProjectStoreError.revisionConflict.localizedDescription)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: \(ProjectStoreError.revisionConflict.localizedDescription)")
        }
    }

    func testBackupImportSaveFailureAfterConfirmClearsPreviewAndDoesNotReportSuccess() async {
        let imported = project(id: "imported", name: "Imported Room")
        var initial = AppFeature.State()
        initial.projectStorageStatus = .loaded
        initial.pendingImport = AppFeature.PendingImport(project: imported, title: "Review backup import", detail: "Ready", successMessage: "Backup imported", expectedRevision: nil, recoveryReason: .beforeImportReplace, kind: .backup, acceptedRows: 1, sourceFormat: .backupJSON)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { _, _, _, _ in
                throw TestSaveFailure()
            })
        }

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .backup
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: Save failed for test.")
        }
    }

    func testRosterImportSaveFailureAfterConfirmClearsPreviewAndLeavesProjectUnchanged() async {
        let original = project(subjects: ["English"])
        var imported = original
        imported.roster = [student()]
        var initial = loadedState(project: original)
        initial.pendingImport = AppFeature.PendingImport(project: imported, title: "Review roster import", detail: "Ready", successMessage: "Roster imported", expectedRevision: original.metadata.persistence?.revision, recoveryReason: .beforeSave, kind: .roster, acceptedRows: 1, sourceFormat: .csv)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(saveProject: { _, _, _, _ in
                throw TestSaveFailure()
            })
        }

        await store.send(.confirmImportTapped) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .roster
            $0.operationStatus = .busy("Saving confirmed import and verifying local storage.")
        }
        await store.receive(.importFailed("Save failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.rosterImportState = .failed("Save failed for test.")
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: Save failed for test.")
        }
    }

    func testResultsImportPickPreparesPreviewWithoutSavingThenConfirmCommits() async {
        let original = project(subjects: ["English"], roster: [student()])
        var imported = original
        imported.results = [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")]
        let preview = importPreview(format: .xlsx, kind: .results, count: 1, project: imported)
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(
                saveProject: { project, _, _, _ in project },
                importResultsFile: { _, _ in preview }
            )
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.xlsx"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .results
            $0.resultsImportState = .validating("Validating results import before changing the project.")
            $0.operationStatus = .busy("Validating results import before changing the project.")
        }
        let pending = AppFeature.PendingImport(project: imported, title: "Review results import", detail: "1 result row validated from XLSX. Confirm to save these results locally.", successMessage: "Results imported, saved, and verified.", expectedRevision: original.metadata.persistence?.revision, recoveryReason: .beforeSave, kind: .results, acceptedRows: 1, sourceFormat: .xlsx)
        await store.receive(.importPreviewPrepared(pending)) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = pending
            $0.selectedTab = .worklist
            $0.activeImportKind = nil
            $0.resultsImportState = .previewReady(count: 1, source: "XLSX")
            $0.operationStatus = .prepared(pending.detail)
            $0.workflowMessage = pending.detail
        }
    }

    func testImportPreviewCancelLeavesSelectedProjectUnchangedAndDoesNotSave() async {
        let original = project(subjects: ["English"])
        var imported = original
        imported.roster = [student()]
        var initial = loadedState(project: original)
        initial.pendingImport = AppFeature.PendingImport(project: imported, title: "Review roster import", detail: "Ready", successMessage: "Roster imported", expectedRevision: original.metadata.persistence?.revision, recoveryReason: .beforeSave, kind: .roster, acceptedRows: 1, sourceFormat: .csv)
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.importPreviewCancelled) {
            $0.rosterImportState = .cancelled("Roster import preview cancelled. No project data changed.")
            $0.projectStorageStatus = .loaded
            $0.activeImportKind = nil
            $0.pendingImport = nil
            $0.operationStatus = .cancelled("Import preview cancelled. No project data changed.")
        }
    }

    func testResultsImportParseFailureDoesNotSaveOrReportSuccess() async {
        let original = project(subjects: ["English"], roster: [student()])
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(importResultsFile: { _, _ in
                throw TestImportFailure()
            })
        }

        await store.send(.resultsImportPicked(URL(fileURLWithPath: "/tmp/results.csv"))) {
            $0.projectStorageStatus = .importing
            $0.activeImportKind = .results
            $0.resultsImportState = .validating("Validating results import before changing the project.")
            $0.operationStatus = .busy("Validating results import before changing the project.")
        }
        await store.receive(.importFailed("Import parse failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.pendingImport = nil
            $0.activeImportKind = nil
            $0.resultsImportState = .failed("Import parse failed for test.")
            $0.operationStatus = .failed("Import stopped before a verified commit. No project data was changed: Import parse failed for test.")
        }
    }

    func testReportExportPreparationFailureClearsExistingPreparedFile() async {
        let ready = readyProject()
        var initial = loadedState(project: ready)
        initial.selectedProjectReadiness = getProjectReadiness(ready)
        initial.preparedFile = AppFeature.PreparedFile(url: URL(fileURLWithPath: "/tmp/old.docx"), label: "Old")
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.projectStoreClient = testProjectStoreClient(prepareReportExport: { _, _ in
                throw TestFilePreparationFailure()
            })
        }

        await store.send(.prepareReportExportTapped(.docx)) {
            $0.projectStorageStatus = .preparingFile
            $0.operationStatus = .busy("Checking readiness and preparing DOCX export.")
        }
        await store.receive(.filePreparationFailed("File preparation failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.preparedFile = nil
            $0.operationStatus = .failed("File could not be prepared: File preparation failed for test.")
        }
    }

    func testFileExporterAndShareCompletionStatusesDistinguishCompletedCancelledAndFailed() async {
        await testShareCancellationAndExportCancellationNeverReportSuccess()
    }

    func testGenerationFailureDoesNotSaveOrReportSuccess() async {
        let original = project(subjects: ["English"], roster: [student()], results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")])
        var initial = loadedState(project: original)
        initial.datasetStatus = .loaded(datasetSnapshot())
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.commentEngineClient = CommentEngineClient { _ in
                throw TestGenerationFailure()
            }
        }

        await store.send(.generateReportsTapped) {
            $0.projectStorageStatus = .generating
            $0.operationStatus = .busy("Generating deterministic draft comments from the bundled production dataset.")
        }
        await store.receive(.reportsGenerationFailed("Generation failed for test.")) {
            $0.projectStorageStatus = .loaded
            $0.operationStatus = .failed("Draft comments were not generated: Generation failed for test.")
        }
    }
}

private struct TestSaveFailure: LocalizedError {
    var errorDescription: String? { "Save failed for test." }
}

private struct TestFilePreparationFailure: LocalizedError {
    var errorDescription: String? { "File preparation failed for test." }
}

private struct TestGenerationFailure: LocalizedError {
    var errorDescription: String? { "Generation failed for test." }
}

private struct TestImportFailure: LocalizedError {
    var errorDescription: String? { "Import parse failed for test." }
}

private struct TestPreparedFileDiscardFailure: LocalizedError {
    var errorDescription: String? { "Prepared file discard failed for test." }
}

private struct TestUnexpectedSave: LocalizedError {
    var errorDescription: String? { "Unexpected save call." }
}

private func XCTAssertProbeValues(
    _ probe: WorkflowProbe,
    _ expected: [String],
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let values = await probe.values()
    XCTAssertEqual(values, expected, file: file, line: line)
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
    listProjectDiagnostics: (@Sendable () async throws -> ProjectListDiagnostics)? = nil,
    createProject: @escaping @Sendable (_ draft: AppFeature.ProjectCreationDraft) async throws -> ProjectSummary = { draft in
        ProjectSummary(id: "p1", name: draft.normalizedName.isEmpty ? "Room 5" : draft.normalizedName, term: draft.normalizedTerm, updatedAt: 1, revision: 1)
    },
    loadProject: @escaping @Sendable (_ id: String) async throws -> Project = { id in project(id: id) },
    saveProject: @escaping @Sendable (_ project: Project, _ expectedRevision: Int?, _ createRecoverySnapshot: Bool, _ recoveryReason: RecoveryReason) async throws -> Project = { project, _, _, _ in project },
    deleteProject: @escaping @Sendable (_ id: String) async throws -> [ProjectSummary] = { _ in [] },
    importRosterFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview = { _, project in importPreview(format: .csv, kind: .roster, count: 0, project: project) },
    importResultsFile: @escaping @Sendable (_ url: URL, _ project: Project) async throws -> PreparedProjectImportPreview = { _, project in importPreview(format: .csv, kind: .results, count: 0, project: project) },
    importBackup: @escaping @Sendable (_ url: URL, _ password: String?) async throws -> Project = { _, _ in project(id: "imported") },
    prepareBackup: @escaping @Sendable (_ project: Project) async throws -> URL = { _ in URL(fileURLWithPath: "/tmp/report-writer-backup.json") },
    prepareEncryptedBackup: @escaping @Sendable (_ project: Project, _ password: String) async throws -> URL = { _, _ in URL(fileURLWithPath: "/tmp/Report_Backup_Copy.cbackup") },
    prepareImportTemplate: @escaping @Sendable (_ kind: CSVTemplateKind, _ format: ImportExportFormat) async throws -> URL = { _, format in URL(fileURLWithPath: "/tmp/report-writer-template.\(format.rawValue)") },
    prepareReportExport: @escaping @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL = { _, format in URL(fileURLWithPath: "/tmp/report-writer-report.\(format.rawValue)") },
    prepareInvalidProjectSupportCopy: @escaping @Sendable (_ recordID: String) async throws -> InvalidProjectSupportCopy = { recordID in
        InvalidProjectSupportCopy(
            recordID: recordID,
            fileURL: URL(fileURLWithPath: "/tmp/Damaged-project-Support-Copy-NOT-A-BACKUP.json"),
            warning: "Raw support copy — not a backup."
        )
    },
    removeInvalidProject: @escaping @Sendable (_ recordID: String) async throws -> ProjectListDiagnostics = { _ in
        ProjectListDiagnostics(projects: [])
    },
    discardPreparedFile: @escaping @Sendable (_ url: URL) async throws -> Void = { _ in },
    purgeStalePreparedFiles: @escaping @Sendable () async throws -> Void = {}
) -> ProjectStoreClient {
    ProjectStoreClient(
        listProjects: listProjects,
        listProjectDiagnostics: listProjectDiagnostics,
        createProject: createProject,
        loadProject: loadProject,
        saveProject: saveProject,
        deleteProject: deleteProject,
        importRosterFile: importRosterFile,
        importResultsFile: importResultsFile,
        importBackup: importBackup,
        prepareBackup: prepareBackup,
        prepareEncryptedBackup: prepareEncryptedBackup,
        prepareImportTemplate: prepareImportTemplate,
        prepareReportExport: prepareReportExport,
        prepareInvalidProjectSupportCopy: prepareInvalidProjectSupportCopy,
        removeInvalidProject: removeInvalidProject,
        discardPreparedFile: discardPreparedFile,
        purgeStalePreparedFiles: purgeStalePreparedFiles
    )
}

private func loadedState(project: Project) -> AppFeature.State {
    var state = AppFeature.State()
    state.projectStorageStatus = .loaded
    state.selectedProject = project
    state.selectedProjectReadiness = getProjectReadiness(project)
    state.projects = [projectSummary(project)]
    state.operationStatus = .saved("Project opened from verified local storage.")
    state.selectedTab = .worklist
    return state
}

private func datasetSnapshot(hash: String = "dataset-hash", normalized: String = "source-hash", loadedAt: Int64? = nil) -> DatasetSnapshot {
    DatasetSnapshot(
        hash: hash,
        normalizedSourceHash: normalized,
        subjectCount: 7,
        componentCount: 56_564,
        recipeCount: 300,
        assembledVariantCount: 4_340,
        uniquenessGuardCount: 12,
        warnings: [],
        summary: "dataset summary",
        loadedAtMilliseconds: loadedAt
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
    revision: Int? = 1,
    subjects: [String] = [],
    roster: [Student] = [],
    results: [AchievementResult] = [],
    reports: [GeneratedReport] = []
) -> Project {
    Project(
        metadata: ProjectMetadata(
            id: id,
            name: name,
            term: term,
            yearLevel: .year5,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            selectedSubjects: Dictionary(uniqueKeysWithValues: subjects.map { ($0, SelectedSubject(name: $0, allStrandsSelected: true)) }),
            useFirstNameOnly: true,
            persistence: ProjectPersistenceMetadata(revision: revision, savedAt: updatedAt, savedBy: "local-ios", fingerprint: "fingerprint-\(id)")
        ),
        roster: roster,
        results: results,
        reports: reports
    )
}

private func student(id: String = "s1", first: String = "Ava", last: String = "Ng", year: StudentYearLevel = .year5) -> Student {
    Student(id: id, firstName: first, lastName: last, yearLevel: year)
}

private func readyProject(id: String = "p1") -> Project {
    let result = AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")
    var project = project(id: id, subjects: ["English"], roster: [student()], results: [result])
    project.reports = [readyReport(project: project, result: result, text: "Ava reads with confidence.")]
    return project
}

private func readyReport(project: Project, result: AchievementResult, text: String) -> GeneratedReport {
    let student = project.roster.first { $0.id == result.studentId } ?? student()
    return GeneratedReport(
        studentId: result.studentId,
        subject: result.subject,
        concreteSubject: result.focusStrand ?? result.subject,
        text: text,
        variantIds: ["v1"],
        isLocked: false,
        generatedAt: 1,
        resultFingerprint: buildGenerationFingerprint(
            projectMetadata: project.metadata,
            student: student,
            result: result,
            concreteSubject: result.focusStrand ?? result.subject
        ),
        reviewedAt: 1
    )
}
