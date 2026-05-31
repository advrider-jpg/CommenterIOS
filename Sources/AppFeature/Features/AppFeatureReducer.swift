import ComposableArchitecture

extension AppFeature {
    func reduceAppAction(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case .task,
             .tabSelected(_),
             .datasetLoaded(_),
             .datasetFailed(_),
             .projectStoreLoaded(_),
             .projectStoreFailed(_):
            return reduceAppLifecycle(&state, action)

        case .createProjectTapped,
             .projectCreateSaved(_),
             .projectCreateFailed(_),
             .projectTapped(_),
             .projectLoaded(_),
             .projectLoadFailed(_),
             .saveProjectTapped,
             .projectSaved(_, _),
             .projectSaveFailed(_),
             .generateReportsTapped,
             .reportsGeneratedAndSaved(_, _),
             .reportsGenerationFailed(_),
             .deleteProjectConfirmed(_),
             .projectDeleted(_, _, _),
             .projectDeleteFailed(_):
            return reduceProjectWorkflow(&state, action)

        case .projectNameChanged(_),
             .projectTermChanged(_),
             .projectYearLevelChanged(_),
             .useFirstNameOnlyChanged(_),
             .addStudentTapped,
             .deleteStudentTapped(_),
             .studentFirstNameChanged(_, _),
             .studentLastNameChanged(_, _),
             .studentYearLevelChanged(_, _),
             .subjectToggled(_),
             .achievementLevelChanged(_, _, _),
             .focusChanged(_, _, _),
             .reportManualEditChanged(_, _, _),
             .reportLockChanged(_, _, _):
            return reduceProjectEditing(&state, action)

        case .rosterImportPicked(_),
             .resultsImportPicked(_),
             .backupImportPicked(_),
             .importCancelled,
             .importPreviewPrepared(_),
             .confirmImportTapped,
             .importPreviewCancelled,
             .importCommitted(_, _),
             .importFailed(_),
             .prepareBackupTapped,
             .prepareReportExportTapped(_),
             .filePrepared(_, _),
             .filePreparationFailed(_),
             .fileExportSaved(_),
             .fileExportCancelled,
             .fileExportFailed(_),
             .fileShareStarted(_),
             .fileShareCompleted(_),
             .fileShareCancelled,
             .fileShareFailed(_),
             .preparedFileDismissed:
            return reduceFileWorkflow(&state, action)
        }
    }
}
