import CommenterDomain
import CommenterImportExport
import ComposableArchitecture
import DesignSystem
import SwiftUI
import UniformTypeIdentifiers

public struct AppView: View {
    private let store: StoreOf<AppFeature>

    @State private var importMode: ImportMode?
    @State private var exportDocument: PreparedExportDocument?
    @State private var isExportingFile = false
    @State private var sharePresentation: SharePresentation?
    @State private var projectDeletionCandidate: ProjectDeletionCandidate?
    @State private var encryptedBackupPassword = ""

    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            TabView(selection: viewStore.binding(get: \.selectedTab, send: AppFeature.Action.tabSelected)) {
                ProjectsRootView(
                    message: viewStore.projectStorageMessage,
                    status: viewStore.projectStorageStatus,
                    projects: viewStore.projects,
                    operationStatus: viewStore.operationStatus,
                    onCreateProject: { viewStore.send(.createProjectTapped) },
                    onOpenProject: { viewStore.send(.projectTapped($0)) },
                    onImportBackup: { importMode = .backup },
                    onDeleteProject: { project in
                        projectDeletionCandidate = ProjectDeletionCandidate(id: project.id, name: project.name)
                    },
                    onDismissStatus: { viewStore.send(.operationStatusDismissed) }
                )
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(AppFeature.Tab.projects)

                WorklistRootView(
                    project: viewStore.selectedProject,
                    readiness: viewStore.selectedProjectReadiness,
                    status: viewStore.projectStorageStatus,
                    aiAvailabilityStatus: viewStore.aiAvailabilityStatus,
                    operationStatus: viewStore.operationStatus,
                    hasUnsavedProjectChanges: viewStore.hasUnsavedProjectChanges,
                    preparedFile: viewStore.preparedFile,
                    pendingImport: viewStore.pendingImport,
                    pendingAIRevision: viewStore.pendingAIRevision,
                    pendingAIRevisions: viewStore.pendingAIRevisions,
                    isBulkAIRevisionRunning: viewStore.isBulkAIRevisionRunning,
                    latestReportCheck: viewStore.latestReportCheck,
                    rosterImportState: viewStore.rosterImportState,
                    resultsImportState: viewStore.resultsImportState,
                    lastPreparedFiles: viewStore.lastPreparedFiles,
                    datasetStatus: viewStore.datasetStatus,
                    onGoToProjects: { viewStore.send(.tabSelected(.projects)) },
                    onProjectNameChanged: { viewStore.send(.projectNameChanged($0)) },
                    onProjectTermChanged: { viewStore.send(.projectTermChanged($0)) },
                    onProjectYearLevelChanged: { viewStore.send(.projectYearLevelChanged($0)) },
                    onUseFirstNameOnlyChanged: { viewStore.send(.useFirstNameOnlyChanged($0)) },
                    onSave: { viewStore.send(.saveProjectTapped) },
                    onDeleteProject: {
                        guard let project = viewStore.selectedProject else { return }
                        projectDeletionCandidate = ProjectDeletionCandidate(
                            id: project.metadata.id,
                            name: project.metadata.name
                        )
                    },
                    onAddStudent: { viewStore.send(.addStudentTapped) },
                    onDeleteStudent: { viewStore.send(.deleteStudentTapped($0)) },
                    onStudentFirstNameChanged: { viewStore.send(.studentFirstNameChanged($0, $1)) },
                    onStudentLastNameChanged: { viewStore.send(.studentLastNameChanged($0, $1)) },
                    onStudentYearChanged: { viewStore.send(.studentYearLevelChanged($0, $1)) },
                    onStudentGenderChanged: { viewStore.send(.studentGenderChanged($0, $1)) },
                    onStudentPronounsChanged: { viewStore.send(.studentPronounsChanged($0, $1)) },
                    onStudentInternalNoteChanged: { viewStore.send(.studentInternalNoteChanged($0, $1)) },
                    onStudentAttitudeDescriptorChanged: { viewStore.send(.studentAttitudeDescriptorChanged($0, $1)) },
                    onSubjectToggled: { viewStore.send(.subjectToggled($0)) },
                    onSelectAllSubjects: { viewStore.send(.subjectSelectAllTapped) },
                    onDeselectAllSubjects: { viewStore.send(.subjectDeselectAllTapped) },
                    onAchievementChanged: { viewStore.send(.achievementLevelChanged($0, $1, $2)) },
                    onFocusChanged: { viewStore.send(.focusChanged($0, $1, $2)) },
                    onResultEvidenceChanged: { viewStore.send(.resultEvidenceChanged($0, $1, $2)) },
                    onResultTextTypeChanged: { viewStore.send(.resultTextTypeChanged($0, $1, $2)) },
                    onResultLearningContextChanged: { viewStore.send(.resultLearningContextChanged($0, $1, $2)) },
                    onResultReportEmphasisNoteChanged: { viewStore.send(.resultReportEmphasisNoteChanged($0, $1, $2)) },
                    onResultFlagChanged: { viewStore.send(.resultFlagChanged($0, $1, $2, $3)) },
                    onResultEnglishFocusTagsChanged: { viewStore.send(.resultEnglishFocusTagsChanged($0, $1, $2)) },
                    onResultMathProficienciesChanged: { viewStore.send(.resultMathProficienciesChanged($0, $1, $2)) },
                    onResultMathMindsetTogglesChanged: { viewStore.send(.resultMathMindsetTogglesChanged($0, $1, $2)) },
                    onResultNextStepGoalsChanged: { viewStore.send(.resultNextStepGoalsChanged($0, $1, $2)) },
                    onGenerate: { viewStore.send(.generateReportsTapped) },
                    onManualEditChanged: { viewStore.send(.reportManualEditChanged($0, $1, $2)) },
                    onLockChanged: { viewStore.send(.reportLockChanged($0, $1, $2)) },
                    onApproveReportForExport: { viewStore.send(.reportApprovedForExport($0, $1)) },
                    onAIPolishReport: { viewStore.send(.reportAIPolishTapped($0, $1)) },
                    onAIToneAdjustReport: { viewStore.send(.reportAIToneAdjustTapped($0, $1)) },
                    onAIDraftFromEvidenceReport: { viewStore.send(.reportAIDraftFromEvidenceTapped($0, $1)) },
                    onBulkAIPolishReports: { viewStore.send(.reportBulkAIPolishTapped) },
                    onCancelBulkAIPolish: { viewStore.send(.reportBulkAIPolishCancelTapped) },
                    onAcceptAIRevision: { viewStore.send(.reportAIRevisionAccepted($0, $1)) },
                    onRejectAIRevision: { viewStore.send(.reportAIRevisionRejected($0, $1)) },
                    onLocalSafetyCheck: { viewStore.send(.reportLocalSafetyCheckTapped($0, $1)) },
                    onValidationWarningsReviewed: { viewStore.send(.reportValidationWarningsReviewed($0, $1)) },
                    onAICritiqueReport: { viewStore.send(.reportAICritiqueTapped($0, $1)) },
                    onAIToneProfileChanged: { viewStore.send(.projectAIToneProfileChanged($0)) },
                    onAITargetLengthChanged: { viewStore.send(.projectAITargetLengthChanged($0)) },
                    onAICustomInstructionChanged: { viewStore.send(.projectAICustomInstructionChanged($0)) },
                    onAIForbiddenMentionsChanged: { viewStore.send(.projectAIForbiddenMentionsChanged($0)) },
                    onAIRequiredMentionsChanged: { viewStore.send(.projectAIRequiredMentionsChanged($0)) },
                    onAISettingsResetBalanced: { viewStore.send(.projectAISettingsResetBalanced) },
                    onReportAIToneProfileChanged: { viewStore.send(.reportAIToneProfileChanged($0, $1, $2)) },
                    onReportAITargetLengthChanged: { viewStore.send(.reportAITargetLengthChanged($0, $1, $2)) },
                    onReportAICustomInstructionChanged: { viewStore.send(.reportAICustomInstructionChanged($0, $1, $2)) },
                    onReportAIForbiddenMentionsChanged: { viewStore.send(.reportAIForbiddenMentionsChanged($0, $1, $2)) },
                    onReportAIRequiredMentionsChanged: { viewStore.send(.reportAIRequiredMentionsChanged($0, $1, $2)) },
                    onReportAIOptionsSavedAsProjectDefaults: { viewStore.send(.reportAIOptionsSavedAsProjectDefaults($0, $1)) },
                    onReportAIOptionsReset: { viewStore.send(.reportAIOptionsReset($0, $1)) },
                    onImportRoster: { importMode = .roster },
                    onImportResults: { importMode = .results },
                    onPrepareBackup: { viewStore.send(.prepareBackupTapped) },
                    onPrepareExport: { viewStore.send(.prepareReportExportTapped($0)) },
                    onSavePreparedFile: {
                        guard let preparedFile = viewStore.preparedFile else {
                            viewStore.send(.fileExportFailed("No verified prepared file is available."))
                            return
                        }
                        do {
                            exportDocument = try PreparedExportDocument(url: preparedFile.url)
                            isExportingFile = true
                        } catch {
                            viewStore.send(.fileExportFailed(userVisibleErrorMessage(error)))
                        }
                    },
                    onSharePreparedFile: {
                        guard let preparedFile = viewStore.preparedFile else {
                            viewStore.send(.fileShareFailed("No verified prepared file is available."))
                            return
                        }
                        sharePresentation = SharePresentation(url: preparedFile.url)
                        viewStore.send(.fileShareStarted(preparedFile.url))
                    },
                    onDismissPreparedFile: { viewStore.send(.preparedFileDismissed) },
                    onDismissStatus: { viewStore.send(.operationStatusDismissed) },
                    onConfirmImport: { viewStore.send(.confirmImportTapped) },
                    onCancelImportPreview: { viewStore.send(.importPreviewCancelled) }
                )
                .tabItem { Label("Work list", systemImage: "checklist") }
                .tag(AppFeature.Tab.worklist)

                SupportRootView(
                    state: viewStore.state,
                    onCopyDiagnostics: { viewStore.send(.copyDiagnosticsTapped) },
                    onDismissStatus: { viewStore.send(.operationStatusDismissed) }
                )
                    .tabItem { Label("Support", systemImage: "questionmark.circle") }
                    .tag(AppFeature.Tab.support)
            }
            .tint(CommenterColors.accent)
            .sensoryFeedback(.selection, trigger: viewStore.selectedTab)
            .task { await viewStore.send(.task).finish() }
            .fileImporter(
                isPresented: importBinding,
                allowedContentTypes: importMode?.allowedContentTypes ?? [.data],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result, viewStore: viewStore)
            }
            .fileExporter(
                isPresented: $isExportingFile,
                document: exportDocument,
                contentType: exportDocument?.contentType ?? .data,
                defaultFilename: exportDocument?.defaultFilename ?? "ReportWriterExport"
            ) { result in
                handleExportResult(result, viewStore: viewStore)
            }
            .sheet(item: $sharePresentation) { presentation in
                ActivityShareSheet(url: presentation.url) { result in
                    handleShareResult(result, url: presentation.url, viewStore: viewStore)
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { viewStore.projectCreationDraft != nil },
                    set: { isPresented in
                        if !isPresented, viewStore.projectCreationDraft != nil, !isCreatingProject(viewStore.projectStorageStatus) {
                            viewStore.send(.projectCreationCancelled)
                        }
                    }
                )
            ) {
                ProjectCreationSheet(
                    draft: viewStore.projectCreationDraft ?? .init(),
                    isSaving: isCreatingProject(viewStore.projectStorageStatus),
                    onNameChanged: { viewStore.send(.projectCreationNameChanged($0)) },
                    onTermChanged: { viewStore.send(.projectCreationTermChanged($0)) },
                    onYearLevelChanged: { viewStore.send(.projectCreationYearLevelChanged($0)) },
                    onUseFirstNameOnlyChanged: { viewStore.send(.projectCreationUseFirstNameOnlyChanged($0)) },
                    onCancel: { viewStore.send(.projectCreationCancelled) },
                    onCreate: { viewStore.send(.confirmCreateProjectTapped) }
                )
                .presentationDetents([.medium, .large])
                .interactiveDismissDisabled(isCreatingProject(viewStore.projectStorageStatus))
            }
            .confirmationDialog(
                "Delete Project?",
                isPresented: Binding(
                    get: { projectDeletionCandidate != nil },
                    set: { isPresented in
                        if !isPresented { projectDeletionCandidate = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: projectDeletionCandidate
            ) { candidate in
                Button("Delete \(candidate.name)", role: .destructive) {
                    projectDeletionCandidate = nil
                    if viewStore.selectedProject?.metadata.id == candidate.id {
                        viewStore.send(.deleteProjectConfirmed(candidate.id))
                    } else {
                        viewStore.send(.projectListDeleteConfirmed(candidate.id))
                    }
                }
                Button("Cancel", role: .cancel) {
                    projectDeletionCandidate = nil
                }
            } message: { _ in
                Text("A recovery snapshot of the verified local project will be created before the project file is removed. Save or reopen first if there are unsaved edits.")
            }
            .alert(
                "Encrypted backup",
                isPresented: Binding(
                    get: { viewStore.pendingEncryptedBackupURL != nil },
                    set: { _ in }
                ),
                presenting: viewStore.pendingEncryptedBackupURL
            ) { url in
                SecureField("Backup password", text: $encryptedBackupPassword)
                Button("Import") {
                    let password = encryptedBackupPassword
                    encryptedBackupPassword = ""
                    viewStore.send(.backupPasswordEntered(url, password))
                }
                Button("Cancel", role: .cancel) {
                    encryptedBackupPassword = ""
                    viewStore.send(.backupPasswordCancelled)
                }
            } message: { _ in
                Text("Enter the password used to encrypt this backup.")
            }
        }
    }

    private var importBinding: Binding<Bool> {
        Binding(
            get: { importMode != nil },
            set: { _ in }
        )
    }

    private func handleImportResult(
        _ result: Result<[URL], Error>,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        defer { importMode = nil }
        switch result {
        case let .success(urls):
            guard let url = urls.first, let mode = importMode else {
                viewStore.send(.importCancelled)
                return
            }
            switch mode {
            case .backup:
                viewStore.send(.backupImportPicked(url))
            case .roster:
                viewStore.send(.rosterImportPicked(url))
            case .results:
                viewStore.send(.resultsImportPicked(url))
            }
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.importCancelled)
            } else {
                viewStore.send(.importFailed(userVisibleErrorMessage(error)))
            }
        }
    }

    private func handleExportResult(
        _ result: Result<URL, Error>,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        switch result {
        case let .success(url):
            viewStore.send(.fileExportSaved(url))
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.fileExportCancelled)
            } else {
                viewStore.send(.fileExportFailed(userVisibleErrorMessage(error)))
            }
        }
    }

    private func handleShareResult(
        _ result: Result<Bool, Error>,
        url: URL,
        viewStore: ViewStore<AppFeature.State, AppFeature.Action>
    ) {
        sharePresentation = nil
        switch result {
        case let .success(completed):
            if completed {
                viewStore.send(.fileShareCompleted(url))
            } else {
                viewStore.send(.fileShareCancelled)
            }
        case let .failure(error):
            if isCancellation(error) {
                viewStore.send(.fileShareCancelled)
            } else {
                viewStore.send(.fileShareFailed(userVisibleErrorMessage(error)))
            }
        }
    }
}

private func isCreatingProject(_ status: AppFeature.ProjectStorageStatus) -> Bool {
    if case .creating = status { return true }
    return false
}

private struct ProjectCreationSheet: View {
    let draft: AppFeature.ProjectCreationDraft
    let isSaving: Bool
    let onNameChanged: (String) -> Void
    let onTermChanged: (String) -> Void
    let onYearLevelChanged: (ProjectYearLevel) -> Void
    let onUseFirstNameOnlyChanged: (Bool) -> Void
    let onCancel: () -> Void
    let onCreate: () -> Void

    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            StationeryScreen(showsDeskFooter: false) {
                StationeryPageHeader("Create project", subtitle: "Start a verified local class file")

                VStack(alignment: .leading, spacing: 10) {
                    TapeLabel("Project details", tone: .action)
                    HandwrittenAnnotation("Name the class before the local project file is created.")
                        .padding(.leading, 4)

                    NotebookCard(showsPaperclip: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            StationeryFormRow("Class name") {
                                TextField("Class name", text: Binding(get: { draft.name }, set: onNameChanged))
                                    .commenterWordsTextInput()
                                    .focused($isNameFocused)
                                    .accessibilityHint("Use a descriptive name, such as 5B Semester 1 2026.")
                                    .accessibilityIdentifier("project-creation-name-field")
                            }

                            StationeryFormRow("Term") {
                                TextField("Term", text: Binding(get: { draft.term }, set: onTermChanged))
                                    .accessibilityIdentifier("project-creation-term-field")
                            }

                            StationeryFormRow("Year level") {
                                Picker("Year level", selection: Binding(get: { draft.yearLevel }, set: onYearLevelChanged)) {
                                    Text("Year 5").tag(ProjectYearLevel.year5)
                                    Text("Year 6").tag(ProjectYearLevel.year6)
                                    Text("Mixed").tag(ProjectYearLevel.mixed)
                                }
                                .pickerStyle(.segmented)
                            }

                            StationeryFormRow("Use first names in reports", detail: "Controls generated wording for students.") {
                                Toggle(
                                    "Use first names in reports",
                                    isOn: Binding(get: { draft.useFirstNameOnly }, set: onUseFirstNameOnlyChanged)
                                )
                                .labelsHidden()
                                .tint(CommenterStationeryTheme.Colors.localGreen)
                            }

                            Text("Projects are stored locally on this device. You can edit these details later from the Work list tab.")
                                .font(.footnote)
                                .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)

                            if isSaving {
                                StationeryStatusChip("Creating and verifying", systemImage: "arrow.triangle.2.circlepath", tone: .local)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create project")
            .commenterInlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onCreate()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(draft.normalizedName.isEmpty || isSaving)
                    .accessibilityIdentifier("project-creation-create-button")
                }
            }
            .onAppear { isNameFocused = true }
        }
    }
}

private struct ProjectDeletionCandidate: Identifiable, Equatable {
    let id: String
    let name: String
}
