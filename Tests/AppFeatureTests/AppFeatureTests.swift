import AppFeature
import ComposableArchitecture
import CommenterAI
import CommenterAITestSupport
import CommentEngine
import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import CommenterReportSafety
import Foundation
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
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
            $0.aiAvailabilityStatus = .checking
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
        await store.receive(.aiAvailabilityLoaded(.unavailable(.foundationModelsFrameworkMissing))) {
            $0.aiAvailabilityStatus = .checked(.unavailable(.foundationModelsFrameworkMissing))
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
            $0.aiAvailabilityStatus = .checking
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
        await store.receive(.aiAvailabilityLoaded(.unavailable(.foundationModelsFrameworkMissing))) {
            $0.aiAvailabilityStatus = .checked(.unavailable(.foundationModelsFrameworkMissing))
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

    func testRosterAddEditDeleteMarksProjectDirtyAndKeepsVisibleState() async {
        var initial = loadedState(project: project(subjects: ["English"]))
        let store = TestStore(initialState: initial) { AppFeature() }

        await store.send(.addStudentTapped) {
            $0.selectedProject?.roster = [Student(id: "student-1", firstName: "", lastName: "", yearLevel: .year5)]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
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
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: No result rows were accepted for import. Existing project data was left unchanged.")
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
        await store.receive(.reportsGeneratedAndSaved(generated, "1 draft comment generated deterministically, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = generated
            $0.selectedProjectReadiness = getProjectReadiness(generated)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("1 draft comment generated deterministically, saved, and verified.")
            $0.workflowMessage = "1 draft comment generated deterministically, saved, and verified."
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
            $0.preparedFile = AppFeature.PreparedFile(url: url, label: "DOCX export file is verified and ready.", format: .docx, preparedAtMilliseconds: 123_456)
            $0.lastPreparedFiles[.docx] = AppFeature.PreparedFileRecord(format: .docx, filename: "Room5.docx", label: "DOCX export file is verified and ready.", preparedAtMilliseconds: 123_456)
            $0.operationStatus = .prepared("DOCX export file is verified and ready.")
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
            $0.operationStatus = .failed("Save or reopen the current project before opening another project.")
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
            $0.operationStatus = .cancelled("File export cancelled. No saved-file success was recorded.")
        }
        await store.send(.fileShareCancelled) {
            $0.operationStatus = .cancelled("Share cancelled. No share success was recorded.")
        }
        await store.send(.fileShareCompleted(preparedURL)) {
            $0.operationStatus = .shared("Share completed for reports.docx.")
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
        XCTAssertTrue(text.contains("broken: Stored project fingerprint verification failed."))
        XCTAssertTrue(text.contains("On-device AI status: Not checked"))
        XCTAssertTrue(text.contains("Backup guidance:"))
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

    func testAIReportApprovalRequiresValidationThenPersistsAsDirtyLocalState() async {
        var original = readyProject()
        let text = "Ava reads with confidence and explains ideas using evidence."
        original.reports[0].generationMode = .aiPolishedDeterministic
        original.reports[0].aiTrace = AIReportTrace(
            traceId: "trace-1",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1,
            inputFingerprint: "input",
            outputFingerprint: stableTextFingerprint(text),
            outcome: .completed
        )
        original.reports[0].currentTextFingerprint = stableTextFingerprint(text)
        original.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview)
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportApprovedForExport("s1", "English")) {
            let fingerprint = stableTextFingerprint(text)
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].approvedTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].lastValidation = ReportValidationSummary(
                status: .passed,
                findings: [],
                validatedAt: 10_000,
                textFingerprint: fingerprint
            )
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(
                status: .approved,
                reviewedAt: 10_000,
                approvedAt: 10_000,
                reviewerDisplayName: "Local teacher",
                approvalFingerprint: fingerprint
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
        }
    }

    func testAIReportApprovalFailureStaysVisibleAndDoesNotApprove() async {
        var original = readyProject()
        original.reports[0].text = "Ava writes about [context]."
        original.reports[0].resultFingerprint = buildGenerationFingerprint(
            projectMetadata: original.metadata,
            student: original.roster[0],
            result: original.results[0],
            concreteSubject: original.reports[0].concreteSubject ?? original.reports[0].subject
        )
        original.reports[0].generationMode = .aiPolishedDeterministic
        original.reports[0].currentTextFingerprint = stableTextFingerprint(original.reports[0].text)
        original.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview)
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportApprovedForExport("s1", "English")) {
            let fingerprint = stableTextFingerprint("Ava writes about [context].")
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].lastValidation = ReportValidationSummary(
                status: .blocked,
                findings: [
                    ReportValidationFinding(
                        id: "placeholder-1-\(stableTextFingerprint("[context]"))",
                        severity: .block,
                        category: .placeholder,
                        message: "Report text contains template or unfinished placeholder text.",
                        excerpt: "[context]",
                        suggestedFix: "Replace the placeholder with final teacher-approved report text."
                    )
                ],
                validatedAt: 10_000,
                textFingerprint: fingerprint
            )
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(
                status: .blockedByValidation,
                reviewedAt: 10_000,
                notes: "Report text contains template or unfinished placeholder text."
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .failed("AI draft cannot be approved until validation blockers are fixed.")
        }
    }

    func testAIReportApprovalBlocksDoNotMentionConstraint() async {
        var original = readyProject()
        original.reports[0].text = "Ava enjoys the lunchtime group and reads with confidence."
        original.reports[0].generationMode = .aiPolishedDeterministic
        original.reports[0].currentTextFingerprint = stableTextFingerprint(original.reports[0].text)
        original.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview)
        original.reports[0].aiOptionsOverride = AIReportOptions(forbiddenMentions: ["lunchtime group"])
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportApprovedForExport("s1", "English")) {
            let fingerprint = stableTextFingerprint("Ava enjoys the lunchtime group and reads with confidence.")
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].lastValidation = ReportValidationSummary(
                status: .blocked,
                findings: [
                    ReportValidationFinding(
                        id: "forbidden-mention-1-\(stableTextFingerprint("lunchtime group"))",
                        severity: .block,
                        category: .forbiddenMention,
                        message: "The report includes a detail the teacher marked as do-not-mention.",
                        excerpt: "lunchtime group",
                        suggestedFix: "Remove the do-not-mention detail before approval or export."
                    )
                ],
                validatedAt: 10_000,
                textFingerprint: fingerprint
            )
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(
                status: .blockedByValidation,
                reviewedAt: 10_000,
                notes: "The report includes a detail the teacher marked as do-not-mention."
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .failed("AI draft cannot be approved until validation blockers are fixed.")
        }
    }

    func testAIReportApprovalBlocksMissingRequiredMentionConstraint() async {
        var original = readyProject()
        original.reports[0].text = "Ava reads with confidence."
        original.reports[0].generationMode = .aiPolishedDeterministic
        original.reports[0].currentTextFingerprint = stableTextFingerprint(original.reports[0].text)
        original.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview)
        original.reports[0].aiOptionsOverride = AIReportOptions(requiredMentions: ["paragraph structure"])
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportApprovedForExport("s1", "English")) {
            let fingerprint = stableTextFingerprint("Ava reads with confidence.")
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].lastValidation = ReportValidationSummary(
                status: .blocked,
                findings: [
                    ReportValidationFinding(
                        id: "required-mention-1-\(stableTextFingerprint("paragraph structure"))",
                        severity: .block,
                        category: .requiredMention,
                        message: "The report is missing a detail the teacher marked as required.",
                        excerpt: "paragraph structure",
                        suggestedFix: "Add the required detail before approval or export, or remove it from this draft's required mentions."
                    )
                ],
                validatedAt: 10_000,
                textFingerprint: fingerprint
            )
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(
                status: .blockedByValidation,
                reviewedAt: 10_000,
                notes: "The report is missing a detail the teacher marked as required."
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .failed("AI draft cannot be approved until validation blockers are fixed.")
        }
    }

    func testReportAIOptionsOverridePersistsAsDirtyDraftStateAndCanReset() async {
        let original = readyProject()
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        }

        await store.send(.reportAIToneProfileChanged("s1", "English", AIToneProfile(warmth: .high, nextStepDirectness: .slightlyHigh))) {
            $0.selectedProject?.reports[0].aiOptionsOverride = AIReportOptions(
                toneProfile: AIToneProfile(warmth: .high, nextStepDirectness: .slightlyHigh)
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's AI tone override changed. Save to persist it on this device.")
        }
        await store.send(.reportAITargetLengthChanged("s1", "English", .shorter)) {
            $0.selectedProject?.reports[0].aiOptionsOverride?.targetLength = .shorter
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's AI length override changed. Save to persist it on this device.")
        }
        await store.send(.reportAIForbiddenMentionsChanged("s1", "English", ["lunchtime group", " ", "lunchtime group", "family detail"])) {
            $0.selectedProject?.reports[0].aiOptionsOverride?.forbiddenMentions = ["family detail", "lunchtime group"]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's do-not-mention constraints changed. Save to persist them on this device.")
        }
        await store.send(.reportAIRequiredMentionsChanged("s1", "English", ["paragraph structure", " ", "paragraph structure", "next step"])) {
            $0.selectedProject?.reports[0].aiOptionsOverride?.requiredMentions = ["next step", "paragraph structure"]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's required-mention constraints changed. Save to persist them on this device.")
        }
        await store.send(.reportAIOptionsReset("s1", "English")) {
            $0.selectedProject?.reports[0].aiOptionsOverride = nil
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft now uses the project AI defaults. Save to persist the reset.")
        }
    }

    func testProjectAISettingsPersistMentionDefaultsAsDirtyProjectState() async {
        let original = readyProject()
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        }

        await store.send(.projectAIForbiddenMentionsChanged(["lunchtime group", " ", "lunchtime group", "family detail"])) {
            $0.selectedProject?.metadata.aiSettings = ProjectAISettings(
                forbiddenMentions: ["family detail", "lunchtime group"]
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Project AI do-not-mention defaults changed. Save to persist them on this device.")
        }
        await store.send(.projectAIRequiredMentionsChanged(["paragraph structure", "next step", "paragraph structure"])) {
            $0.selectedProject?.metadata.aiSettings?.requiredMentions = ["next step", "paragraph structure"]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Project AI required-mention defaults changed. Save to persist them on this device.")
        }
        await store.send(.projectAISettingsResetBalanced) {
            $0.selectedProject?.metadata.aiSettings = nil
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Project AI defaults reset to balanced settings. Save to persist the reset.")
        }
    }

    func testReportAIOptionsOverridePreservesProjectDefaultsWhenChangingOneField() async {
        var original = readyProject()
        original.metadata.aiSettings = ProjectAISettings(
            defaultToneProfile: AIToneProfile(warmth: .slightlyHigh, specificity: .high),
            targetLength: .fuller,
            customInstruction: "Use the school's strengths-based voice.",
            forbiddenMentions: ["lunchtime group"],
            requiredMentions: ["paragraph structure"]
        )
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        }

        await store.send(.reportAITargetLengthChanged("s1", "English", .shorter)) {
            $0.selectedProject?.reports[0].aiOptionsOverride = AIReportOptions(
                toneProfile: AIToneProfile(warmth: .slightlyHigh, specificity: .high),
                targetLength: .shorter,
                customInstruction: "Use the school's strengths-based voice.",
                forbiddenMentions: ["lunchtime group"],
                requiredMentions: ["paragraph structure"]
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's AI length override changed. Save to persist it on this device.")
        }
    }

    func testReportAIOptionsCanBeSavedAsProjectDefaults() async {
        var original = readyProject()
        original.metadata.aiSettings = ProjectAISettings(defaultToneProfile: AIToneProfile(warmth: .low))
        original.reports[0].aiOptionsOverride = AIReportOptions(
            toneProfile: AIToneProfile(warmth: .high, specificity: .slightlyHigh),
            targetLength: .fuller,
            customInstruction: "Use the team voice.",
            forbiddenMentions: ["lunchtime group"],
            requiredMentions: ["paragraph structure"]
        )
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        }

        await store.send(.reportAIOptionsSavedAsProjectDefaults("s1", "English")) {
            $0.selectedProject?.metadata.aiSettings = ProjectAISettings(
                defaultToneProfile: AIToneProfile(warmth: .high, specificity: .slightlyHigh),
                targetLength: .fuller,
                customInstruction: "Use the team voice.",
                forbiddenMentions: ["lunchtime group"],
                requiredMentions: ["paragraph structure"]
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("This draft's AI settings were saved as project defaults. Save to persist them on this device.")
        }
    }

    func testAIPolishUsesReportSpecificOptionsWhenPresent() async {
        var original = readyProject()
        original.reports[0].aiOptionsOverride = AIReportOptions(
            toneProfile: AIToneProfile(warmth: .high),
            targetLength: .shorter,
            customInstruction: "Keep it concise.",
            forbiddenMentions: ["lunchtime group"],
            requiredMentions: ["paragraph structure"]
        )
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 2_000, textFingerprint: "fp")
        let trace = AIReportTrace(
            traceId: "trace-options",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            inputFingerprint: "input",
            outcome: .completed
        )
        let probe = WorkflowProbe()
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = AIClient(
                availability: { .available },
                reviseDeterministicDraft: { request in
                    XCTAssertEqual(request.options.targetLength, .shorter)
                    XCTAssertEqual(request.options.toneProfile.warmth, .high)
                    XCTAssertEqual(request.options.customInstruction, "Keep it concise.")
                    XCTAssertEqual(request.options.forbiddenMentions, ["lunchtime group"])
                    XCTAssertEqual(request.options.requiredMentions, ["paragraph structure"])
                    await probe.record("options-used")
                    return AIReportRevisionResult(
                        revisedText: "Ava reads with confidence.",
                        changeSummary: "No change.",
                        validation: validation,
                        trace: trace
                    )
                },
                adjustTone: { _ in throw AIClientError.generationNotImplemented },
                draftFromEvidence: { _ in throw AIClientError.generationNotImplemented },
                critiqueReport: { _ in AIReportCritiqueResult(validation: validation) },
                extractReportSafeFacts: { _ in ReportSafeFactExtractionResult(facts: []) }
            )
        }

        await store.send(.reportAIPolishTapped("s1", "English")) {
            $0.pendingAIRevision = nil
            $0.latestReportCheck = nil
            $0.operationStatus = .busy("Requesting an on-device AI revision for teacher review.")
        }
        await store.receive(.reportAIPolishCompleted("s1", "English", AIReportRevisionResult(
            revisedText: "Ava reads with confidence.",
            changeSummary: "No change.",
            validation: validation,
            trace: trace
        ))) {
            $0.pendingAIRevision = AppFeature.PendingAIRevision(
                id: "trace-options",
                studentId: "s1",
                subject: "English",
                originalText: "Ava reads with confidence.",
                proposedText: "Ava reads with confidence.",
                changeSummary: "No change.",
                validation: validation,
                trace: trace
            )
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "ai-preview-trace-options",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.operationStatus = .prepared("AI revision preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
        }
        await XCTAssertProbeValues(probe, ["options-used"])
    }

    func testAIDraftFromEvidenceQueuesPreviewAndAcceptsAsEvidenceDraft() async {
        var result = AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")
        result.evidenceText = "Ava uses textual evidence when explaining her ideas."
        var original = project(subjects: ["English"], roster: [student()], results: [result])
        original.reports = [readyReport(project: original, result: result, text: "Ava reads with confidence.")]
        let draftText = "Ava uses textual evidence to explain her ideas clearly."
        let validation = ReportValidationSummary(
            status: .passed,
            findings: [],
            validatedAt: 2_000,
            textFingerprint: stableTextFingerprint(draftText)
        )
        let trace = AIReportTrace(
            traceId: "trace-draft-evidence",
            promptId: "report.draft.evidence.v1",
            promptVersion: "1.0.0",
            promptPurpose: .draftFromEvidence,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            completedAt: 2_000,
            inputFingerprint: "input",
            outputFingerprint: stableTextFingerprint(draftText),
            validationSummary: validation,
            outcome: .completed
        )
        let probe = WorkflowProbe()
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = AIClient(
                availability: { .available },
                reviseDeterministicDraft: { _ in throw AIClientError.generationNotImplemented },
                adjustTone: { _ in throw AIClientError.generationNotImplemented },
                draftFromEvidence: { request in
                    XCTAssertEqual(request.evidence.map(\.source), [.achievementResultEvidence])
                    XCTAssertEqual(request.evidence.map(\.text), ["Ava uses textual evidence when explaining her ideas."])
                    await probe.record("evidence-draft-requested")
                    return AIReportDraftResult(draftText: draftText, validation: validation, trace: trace)
                },
                critiqueReport: { _ in AIReportCritiqueResult(validation: validation) },
                extractReportSafeFacts: { _ in ReportSafeFactExtractionResult(facts: []) }
            )
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportAIDraftFromEvidenceTapped("s1", "English")) {
            $0.pendingAIRevision = nil
            $0.latestReportCheck = nil
            $0.operationStatus = .busy("Requesting an on-device AI draft from report-safe evidence for teacher review.")
        }
        let pending = AppFeature.PendingAIRevision(
            id: "trace-draft-evidence",
            studentId: "s1",
            subject: "English",
            originalText: "Ava reads with confidence.",
            proposedText: draftText,
            changeSummary: "Drafted from report-safe evidence.",
            validation: validation,
            trace: trace
        )
        await store.receive(.reportAIDraftFromEvidenceCompleted("s1", "English", AIReportDraftResult(draftText: draftText, validation: validation, trace: trace))) {
            $0.pendingAIRevision = pending
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "ai-draft-preview-trace-draft-evidence",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.operationStatus = .prepared("AI evidence draft preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
        }

        await store.send(.reportAIRevisionAccepted("s1", "English")) {
            let fingerprint = stableTextFingerprint(draftText)
            var acceptedTrace = trace
            acceptedTrace.validationSummary = validation
            acceptedTrace.outputFingerprint = fingerprint
            acceptedTrace.outcome = .completed
            $0.selectedProject?.reports[0].manualEdit = draftText
            $0.selectedProject?.reports[0].generationMode = .aiDraftFromEvidence
            $0.selectedProject?.reports[0].aiTrace = acceptedTrace
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].approvedTextFingerprint = nil
            $0.selectedProject?.reports[0].lastValidation = validation
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview, reviewedAt: 10_000)
            $0.selectedProject?.reports[0].revisionHistory = [
                ReportRevisionRecord(
                    id: "revision-10000-\(fingerprint)",
                    createdAt: 10_000,
                    generationMode: .aiDraftFromEvidence,
                    previousTextFingerprint: stableTextFingerprint("Ava reads with confidence."),
                    newTextFingerprint: fingerprint,
                    summary: "Drafted from report-safe evidence.",
                    traceId: "trace-draft-evidence"
                )
            ]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "accepted-trace-draft-evidence",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("AI revision accepted into the local draft. Save the project, then approve the current AI draft before export.")
        }
        await XCTAssertProbeValues(probe, ["evidence-draft-requested"])
    }

    func testAIDraftFromEvidenceRequiresReportSafeEvidence() async {
        var initial = loadedState(project: readyProject())
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.reportAIDraftFromEvidenceTapped("s1", "English")) {
            $0.operationStatus = .failed("Add report-safe evidence, learning context, or a report emphasis note before requesting an AI evidence draft.")
        }
    }

    func testAIPolishPreviewDoesNotOverwriteUntilTeacherAccepts() async {
        let original = readyProject()
        let revisedText = "Ava reads with confidence and explains ideas clearly."
        let validation = ReportValidationSummary(
            status: .passed,
            findings: [],
            validatedAt: 2_000,
            textFingerprint: stableTextFingerprint(revisedText)
        )
        let trace = AIReportTrace(
            traceId: "trace-polish-1",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            completedAt: 2_000,
            inputFingerprint: "input-fp",
            deterministicDraftFingerprint: stableTextFingerprint(original.reports[0].text),
            outputFingerprint: stableTextFingerprint(revisedText),
            validationSummary: validation,
            outcome: .completed
        )
        let revision = AIReportRevisionResult(
            revisedText: revisedText,
            changeSummary: "Improved flow and clarity.",
            validation: validation,
            trace: trace,
            reviewWarnings: ["Confirm the wording matches classroom evidence."]
        )
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = .configuredForTests(revisionResult: revision)
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportAIPolishTapped("s1", "English")) {
            $0.pendingAIRevision = nil
            $0.latestReportCheck = nil
            $0.operationStatus = .busy("Requesting an on-device AI revision for teacher review.")
        }
        let pending = AppFeature.PendingAIRevision(
            id: "trace-polish-1",
            studentId: "s1",
            subject: "English",
            originalText: original.reports[0].text,
            proposedText: revisedText,
            changeSummary: "Improved flow and clarity.",
            validation: validation,
            trace: trace,
            reviewWarnings: ["Confirm the wording matches classroom evidence."]
        )
        await store.receive(.reportAIPolishCompleted("s1", "English", revision)) {
            $0.pendingAIRevision = pending
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "ai-preview-trace-polish-1",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Confirm the wording matches classroom evidence."]
            )
            $0.operationStatus = .prepared("AI revision preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
        }

        await store.send(.reportAIRevisionAccepted("s1", "English")) {
            let fingerprint = stableTextFingerprint(revisedText)
            var acceptedTrace = trace
            acceptedTrace.validationSummary = validation
            acceptedTrace.outputFingerprint = fingerprint
            acceptedTrace.outcome = .completed
            $0.selectedProject?.reports[0].manualEdit = revisedText
            $0.selectedProject?.reports[0].generationMode = .aiPolishedDeterministic
            $0.selectedProject?.reports[0].aiTrace = acceptedTrace
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].approvedTextFingerprint = nil
            $0.selectedProject?.reports[0].lastValidation = validation
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview, reviewedAt: 10_000)
            $0.selectedProject?.reports[0].revisionHistory = [
                ReportRevisionRecord(
                    id: "revision-10000-\(fingerprint)",
                    createdAt: 10_000,
                    generationMode: .aiPolishedDeterministic,
                    previousTextFingerprint: stableTextFingerprint(original.reports[0].text),
                    newTextFingerprint: fingerprint,
                    summary: "Improved flow and clarity.",
                    traceId: "trace-polish-1"
                )
            ]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "accepted-trace-polish-1",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Confirm the wording matches classroom evidence."]
            )
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("AI revision accepted into the local draft. Save the project, then approve the current AI draft before export.")
        }
    }

    func testAIToneAdjustmentQueuesPreviewAndAcceptsAsToneAdjustedDraft() async {
        let original = readyProject()
        let adjustedText = "Ava reads with warm confidence and explains ideas clearly."
        let validation = ReportValidationSummary(
            status: .passed,
            findings: [],
            validatedAt: 2_000,
            textFingerprint: stableTextFingerprint(adjustedText)
        )
        let trace = AIReportTrace(
            traceId: "trace-tone-1",
            promptId: "report.adjust.tone.v1",
            promptVersion: "1.0.0",
            promptPurpose: .adjustTone,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            completedAt: 2_000,
            inputFingerprint: "input-fp",
            deterministicDraftFingerprint: stableTextFingerprint(original.reports[0].text),
            outputFingerprint: stableTextFingerprint(adjustedText),
            validationSummary: validation,
            outcome: .completed
        )
        let revision = AIReportRevisionResult(
            revisedText: adjustedText,
            changeSummary: "Adjusted tone only.",
            validation: validation,
            trace: trace,
            reviewWarnings: ["Confirm the tone still matches the teacher's intent."]
        )
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = .configuredForTests(toneAdjustmentResult: revision)
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportAIToneAdjustTapped("s1", "English")) {
            $0.pendingAIRevision = nil
            $0.latestReportCheck = nil
            $0.operationStatus = .busy("Requesting an on-device AI tone adjustment for teacher review.")
        }
        let pending = AppFeature.PendingAIRevision(
            id: "trace-tone-1",
            studentId: "s1",
            subject: "English",
            originalText: original.reports[0].text,
            proposedText: adjustedText,
            changeSummary: "Adjusted tone only.",
            validation: validation,
            trace: trace,
            reviewWarnings: ["Confirm the tone still matches the teacher's intent."]
        )
        await store.receive(.reportAIToneAdjustCompleted("s1", "English", revision)) {
            $0.pendingAIRevision = pending
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "ai-tone-preview-trace-tone-1",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Confirm the tone still matches the teacher's intent."]
            )
            $0.operationStatus = .prepared("AI tone-adjusted preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
        }

        await store.send(.reportAIRevisionAccepted("s1", "English")) {
            let fingerprint = stableTextFingerprint(adjustedText)
            var acceptedTrace = trace
            acceptedTrace.validationSummary = validation
            acceptedTrace.outputFingerprint = fingerprint
            acceptedTrace.outcome = .completed
            $0.selectedProject?.reports[0].manualEdit = adjustedText
            $0.selectedProject?.reports[0].generationMode = .aiToneAdjusted
            $0.selectedProject?.reports[0].aiTrace = acceptedTrace
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].approvedTextFingerprint = nil
            $0.selectedProject?.reports[0].lastValidation = validation
            $0.selectedProject?.reports[0].reviewState = ReportReviewState(status: .needsTeacherReview, reviewedAt: 10_000)
            $0.selectedProject?.reports[0].revisionHistory = [
                ReportRevisionRecord(
                    id: "revision-10000-\(fingerprint)",
                    createdAt: 10_000,
                    generationMode: .aiToneAdjusted,
                    previousTextFingerprint: stableTextFingerprint(original.reports[0].text),
                    newTextFingerprint: fingerprint,
                    summary: "Adjusted tone only.",
                    traceId: "trace-tone-1"
                )
            ]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "accepted-trace-tone-1",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Confirm the tone still matches the teacher's intent."]
            )
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("AI revision accepted into the local draft. Save the project, then approve the current AI draft before export.")
        }
    }

    func testAIRevisionRejectDoesNotDirtyOrChangeProject() async {
        let original = readyProject()
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 2, textFingerprint: "fp")
        let trace = AIReportTrace(
            traceId: "trace-reject",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1,
            inputFingerprint: "input",
            outcome: .completed
        )
        var initial = loadedState(project: original)
        initial.pendingAIRevision = AppFeature.PendingAIRevision(
            id: "trace-reject",
            studentId: "s1",
            subject: "English",
            originalText: original.reports[0].text,
            proposedText: "Ava reads with confidence and clarity.",
            changeSummary: "Improved flow.",
            validation: validation,
            trace: trace
        )
        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.reportAIRevisionRejected("s1", "English")) {
            $0.pendingAIRevision = nil
            $0.operationStatus = .cancelled("AI revision discarded. The local draft was not changed.")
        }
    }

    func testBulkAIPolishQueuesPreviewsWithoutChangingProject() async {
        let resultOne = AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")
        let resultTwo = AchievementResult(studentId: "s2", subject: "English", achievementLevel: .atStandard, focusStrand: "Writing")
        var original = project(
            subjects: ["English"],
            roster: [student(id: "s1", first: "Ava"), student(id: "s2", first: "Ben", last: "Vale")],
            results: [resultOne, resultTwo]
        )
        original.reports = [
            readyReport(project: original, result: resultOne, text: "Ava reads with confidence."),
            readyReport(project: original, result: resultTwo, text: "Ben writes with confidence.")
        ]
        let revisedText = "A revised report preview."
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 2_000, textFingerprint: stableTextFingerprint(revisedText))
        let trace = AIReportTrace(
            traceId: "bulk-trace",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            completedAt: 2_000,
            inputFingerprint: "input",
            outputFingerprint: stableTextFingerprint(revisedText),
            outcome: .completed
        )
        let revision = AIReportRevisionResult(revisedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace)
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = .configuredForTests(revisionResult: revision)
        }

        await store.send(.reportBulkAIPolishTapped) {
            $0.pendingAIRevision = nil
            $0.latestReportCheck = nil
            $0.isBulkAIRevisionRunning = true
            $0.operationStatus = .busy("Requesting bulk on-device AI revisions for teacher review.")
        }
        let firstCompleted = AppFeature.CompletedAIRevision(studentId: "s1", subject: "English", originalText: "Ava reads with confidence.", result: revision)
        let secondCompleted = AppFeature.CompletedAIRevision(studentId: "s2", subject: "English", originalText: "Ben writes with confidence.", result: revision)
        let completed = [firstCompleted, secondCompleted]
        let firstPreviewId = "bulk-trace-s1-\(stableTextFingerprint("English"))"
        let secondPreviewId = "bulk-trace-s2-\(stableTextFingerprint("English"))"
        await store.receive(.reportBulkAIPolishProgress(firstCompleted)) {
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = [
                AppFeature.PendingAIRevision(id: firstPreviewId, studentId: "s1", subject: "English", originalText: "Ava reads with confidence.", proposedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace)
            ]
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "bulk-preview-\(firstPreviewId)",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.operationStatus = .busy("Bulk AI revision queued 1 teacher-review preview.")
        }
        await store.receive(.reportBulkAIPolishProgress(secondCompleted)) {
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = [
                AppFeature.PendingAIRevision(id: firstPreviewId, studentId: "s1", subject: "English", originalText: "Ava reads with confidence.", proposedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace),
                AppFeature.PendingAIRevision(id: secondPreviewId, studentId: "s2", subject: "English", originalText: "Ben writes with confidence.", proposedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace)
            ]
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "bulk-preview-\(secondPreviewId)",
                studentId: "s2",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.operationStatus = .busy("Bulk AI revision queued 2 teacher-review previews.")
        }
        await store.receive(.reportBulkAIPolishCompleted(completed, [])) {
            $0.isBulkAIRevisionRunning = false
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = [
                AppFeature.PendingAIRevision(id: firstPreviewId, studentId: "s1", subject: "English", originalText: "Ava reads with confidence.", proposedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace),
                AppFeature.PendingAIRevision(id: secondPreviewId, studentId: "s2", subject: "English", originalText: "Ben writes with confidence.", proposedText: revisedText, changeSummary: "Bulk revision.", validation: validation, trace: trace)
            ]
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "bulk-preview-\(firstPreviewId)",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: []
            )
            $0.operationStatus = .prepared("2 AI revision previews are ready for teacher review.")
        }
    }

    func testBulkAIPolishCancelKeepsCompletedPreviewsAndLeavesDraftsUnchanged() async {
        let original = readyProject()
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 2_000, textFingerprint: "fp")
        let trace = AIReportTrace(
            traceId: "bulk-cancel-trace",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            inputFingerprint: "input",
            outcome: .completed
        )
        let pending = AppFeature.PendingAIRevision(
            id: "bulk-cancel-trace-s1-\(stableTextFingerprint("English"))",
            studentId: "s1",
            subject: "English",
            originalText: original.reports[0].text,
            proposedText: "A revised preview.",
            changeSummary: "Bulk revision.",
            validation: validation,
            trace: trace
        )
        var initial = loadedState(project: original)
        initial.isBulkAIRevisionRunning = true
        initial.pendingAIRevisions = [pending]
        initial.operationStatus = .busy("Bulk AI revision queued 1 teacher-review preview.")
        let store = TestStore(initialState: initial) {
            AppFeature()
        }

        await store.send(.reportBulkAIPolishCancelTapped) {
            $0.isBulkAIRevisionRunning = false
            $0.operationStatus = .cancelled("Bulk AI revision cancelled. Queued drafts were left unchanged. 1 completed preview remains available for teacher review.")
        }
    }

    func testAIReviewQueueCountCombinesSingleAndBulkPreviewsByReportKey() {
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 2_000, textFingerprint: "fp")
        let trace = AIReportTrace(
            traceId: "queue-trace",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1_000,
            inputFingerprint: "input",
            outcome: .completed
        )
        var state = loadedState(project: readyProject())
        state.pendingAIRevision = AppFeature.PendingAIRevision(
            id: "single",
            studentId: "s1",
            subject: "English",
            originalText: "Ava reads with confidence.",
            proposedText: "Ava reads with confidence.",
            changeSummary: "Single.",
            validation: validation,
            trace: trace
        )
        state.pendingAIRevisions = [
            AppFeature.PendingAIRevision(
                id: "duplicate",
                studentId: "s1",
                subject: "English",
                originalText: "Ava reads with confidence.",
                proposedText: "Ava reads with confidence.",
                changeSummary: "Duplicate.",
                validation: validation,
                trace: trace
            ),
            AppFeature.PendingAIRevision(
                id: "second",
                studentId: "s2",
                subject: "English",
                originalText: "Ben writes with confidence.",
                proposedText: "Ben writes with confidence.",
                changeSummary: "Second.",
                validation: validation,
                trace: trace
            )
        ]

        XCTAssertEqual(state.aiReviewQueueCount, 2)
    }

    func testLocalSafetyCheckPersistsRealValidationFindings() async {
        var original = readyProject()
        original.reports[0].text = "Ava writes about [context]."
        var initial = loadedState(project: original)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 10_000 })
        }

        await store.send(.reportLocalSafetyCheckTapped("s1", "English"))
        let fingerprint = stableTextFingerprint("Ava writes about [context].")
        let validation = ReportValidationSummary(
            status: .blocked,
            findings: [
                ReportValidationFinding(
                    id: "placeholder-1-\(stableTextFingerprint("[context]"))",
                    severity: .block,
                    category: .placeholder,
                    message: "Report text contains template or unfinished placeholder text.",
                    excerpt: "[context]",
                    suggestedFix: "Replace the placeholder with final teacher-approved report text."
                )
            ],
            validatedAt: 10_000,
            textFingerprint: fingerprint
        )
        await store.receive(.reportLocalSafetyCheckCompleted("s1", "English", AIReportCritiqueResult(
            validation: validation,
            reviewNotes: ["Report text contains template or unfinished placeholder text. Replace the placeholder with final teacher-approved report text."]
        ))) {
            $0.selectedProject?.reports[0].currentTextFingerprint = fingerprint
            $0.selectedProject?.reports[0].lastValidation = validation
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "check-s1-English-\(fingerprint)",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Report text contains template or unfinished placeholder text. Replace the placeholder with final teacher-approved report text."]
            )
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Local safety check found validation blockers. Save the project to persist the validation record on this device.")
        }
    }

    func testAICritiquePersistsReviewNotesWithoutChangingDraftText() async {
        let original = readyProject()
        let validation = ReportValidationSummary(
            status: .passedWithWarnings,
            findings: [
                ReportValidationFinding(
                    id: "tone-warning",
                    severity: .warning,
                    category: .tone,
                    message: "Check that the report includes enough evidence."
                )
            ],
            validatedAt: 20_000,
            textFingerprint: stableTextFingerprint(original.reports[0].text)
        )
        let critique = AIReportCritiqueResult(
            validation: validation,
            reviewNotes: ["Add one more evidence detail if the teacher can verify it."]
        )
        let probe = WorkflowProbe()
        var initial = loadedState(project: original)
        initial.aiAvailabilityStatus = .checked(.available)
        let store = TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.aiClient = AIClient(
                availability: { .available },
                reviseDeterministicDraft: { _ in throw AIClientError.generationNotImplemented },
                adjustTone: { _ in throw AIClientError.generationNotImplemented },
                draftFromEvidence: { _ in throw AIClientError.generationNotImplemented },
                critiqueReport: { request in
                    XCTAssertEqual(request.text, "Ava reads with confidence.")
                    await probe.record("critique-requested")
                    return critique
                },
                extractReportSafeFacts: { _ in ReportSafeFactExtractionResult(facts: []) }
            )
        }

        await store.send(.reportAICritiqueTapped("s1", "English")) {
            $0.latestReportCheck = nil
            $0.operationStatus = .busy("Requesting an on-device AI critique for teacher review.")
        }
        await store.receive(.reportAICritiqueCompleted("s1", "English", critique)) {
            $0.selectedProject?.reports[0].currentTextFingerprint = validation.textFingerprint
            $0.selectedProject?.reports[0].lastValidation = validation
            $0.selectedProject?.reports[0].latestAIReviewNotes = ["Add one more evidence detail if the teacher can verify it."]
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = AppFeature.ReportCheckResult(
                id: "ai-critique-s1-English-\(validation.textFingerprint)",
                studentId: "s1",
                subject: "English",
                validation: validation,
                reviewNotes: ["Add one more evidence detail if the teacher can verify it."]
            )
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Local safety check found 1 warning item. AI critique notes were stored locally for teacher review. Save the project to persist them on this device.")
        }
        XCTAssertEqual(store.state.selectedProject?.reports[0].exportText, "Ava reads with confidence.")
        await XCTAssertProbeValues(probe, ["critique-requested"])
    }

    func testValidationWarningsCanBeMarkedReviewedForCurrentDraft() async {
        var original = readyProject()
        let fingerprint = stableTextFingerprint(original.reports[0].text)
        original.reports[0].currentTextFingerprint = fingerprint
        original.reports[0].lastValidation = ReportValidationSummary(
            status: .passedWithWarnings,
            findings: [
                ReportValidationFinding(
                    id: "unsupported-1",
                    severity: .warning,
                    category: .unsupportedFact,
                    message: "Confirm the claim is supported."
                )
            ],
            validatedAt: 20_000,
            textFingerprint: fingerprint
        )
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        } withDependencies: {
            $0.dateClient = DateClient(nowMilliseconds: { 21_000 })
        }

        await store.send(.reportValidationWarningsReviewed("s1", "English")) {
            $0.selectedProject?.reports[0].validationWarningReview = ReportWarningReviewRecord(
                validationFingerprint: fingerprint,
                reviewedAt: 21_000,
                reviewerDisplayName: "Local teacher",
                notes: "Confirm the claim is supported."
            )
            $0.selectedProjectReadiness = getProjectReadiness($0.selectedProject!)
            $0.pendingAIRevision = nil
            $0.pendingAIRevisions = []
            $0.latestReportCheck = nil
            $0.hasUnsavedProjectChanges = true
            $0.operationStatus = .dirty("Validation warnings marked reviewed for the current draft. Save to persist the review.")
        }
    }

    func testValidationWarningReviewDoesNotBypassBlockers() async {
        var original = readyProject()
        let fingerprint = stableTextFingerprint("Ava writes about [context].")
        original.reports[0].manualEdit = "Ava writes about [context]."
        original.reports[0].lastValidation = ReportValidationSummary(
            status: .blocked,
            findings: [
                ReportValidationFinding(
                    id: "placeholder-1",
                    severity: .block,
                    category: .placeholder,
                    message: "Report text contains template or unfinished placeholder text."
                )
            ],
            validatedAt: 20_000,
            textFingerprint: fingerprint
        )
        let store = TestStore(initialState: loadedState(project: original)) {
            AppFeature()
        }

        await store.send(.reportValidationWarningsReviewed("s1", "English")) {
            $0.operationStatus = .failed("Validation blockers must be fixed before warnings can be marked reviewed.")
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
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Import parse failed for test.")
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
        await store.receive(.reportsGeneratedAndSaved(generated, "1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified.")) {
            $0.projectStorageStatus = .loaded
            $0.selectedProject = generated
            $0.selectedProjectReadiness = getProjectReadiness(generated)
            $0.pendingImport = nil
            $0.preparedFile = nil
            $0.operationStatus = .saved("1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified.")
            $0.workflowMessage = "1 draft comment generated deterministically, 1 locked draft left unchanged, saved, and verified."
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
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Save failed for test.")
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
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Save failed for test.")
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
            $0.rosterImportState = .failed("Roster import preview cancelled. No project data changed.")
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
            $0.operationStatus = .failed("Import failed. Project data was left unchanged: Import parse failed for test.")
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
            $0.preparedFile = nil
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
    prepareReportExport: @escaping @Sendable (_ project: Project, _ format: ImportExportFormat) async throws -> URL = { _, format in URL(fileURLWithPath: "/tmp/report-writer-report.\(format.rawValue)") }
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
        prepareReportExport: prepareReportExport
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

private func readyProject() -> Project {
    let result = AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Reading")
    var project = project(subjects: ["English"], roster: [student()], results: [result])
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
        )
    )
}
