import CommentEngine
import CommenterDomain
import CommenterImportExport
import DesignSystem
import SwiftUI

struct WorklistRootView: View {
    let project: Project?
    let readiness: ProjectReadiness?
    let status: AppFeature.ProjectStorageStatus
    let aiAvailabilityStatus: AppFeature.AIAvailabilityStatus
    let operationStatus: AppFeature.OperationStatus
    let hasUnsavedProjectChanges: Bool
    let preparedFile: AppFeature.PreparedFile?
    let pendingImport: AppFeature.PendingImport?
    let pendingAIRevision: AppFeature.PendingAIRevision?
    let pendingAIRevisions: [AppFeature.PendingAIRevision]
    let isBulkAIRevisionRunning: Bool
    let latestReportCheck: AppFeature.ReportCheckResult?
    let rosterImportState: AppFeature.TabularImportState
    let resultsImportState: AppFeature.TabularImportState
    let lastPreparedFiles: [ImportExportFormat: AppFeature.PreparedFileRecord]
    let datasetStatus: AppFeature.DatasetStatus
    let onGoToProjects: () -> Void
    let onProjectNameChanged: (String) -> Void
    let onProjectTermChanged: (String) -> Void
    let onProjectYearLevelChanged: (ProjectYearLevel) -> Void
    let onUseFirstNameOnlyChanged: (Bool) -> Void
    let onSave: () -> Void
    let onDeleteProject: () -> Void
    let onAddStudent: () -> Void
    let onDeleteStudent: (String) -> Void
    let onStudentFirstNameChanged: (String, String) -> Void
    let onStudentLastNameChanged: (String, String) -> Void
    let onStudentYearChanged: (String, StudentYearLevel) -> Void
    let onStudentGenderChanged: (String, Gender?) -> Void
    let onStudentPronounsChanged: (String, String) -> Void
    let onStudentInternalNoteChanged: (String, String) -> Void
    let onStudentAttitudeDescriptorChanged: (String, String) -> Void
    let onSubjectToggled: (String) -> Void
    let onSelectAllSubjects: () -> Void
    let onDeselectAllSubjects: () -> Void
    let onAchievementChanged: (String, String, AchievementLevel?) -> Void
    let onFocusChanged: (String, String, String) -> Void
    let onResultEvidenceChanged: (String, String, String) -> Void
    let onResultTextTypeChanged: (String, String, String) -> Void
    let onResultLearningContextChanged: (String, String, String) -> Void
    let onResultReportEmphasisNoteChanged: (String, String, String) -> Void
    let onResultFlagChanged: (String, String, String, Bool) -> Void
    let onResultEnglishFocusTagsChanged: (String, String, [String]) -> Void
    let onResultMathProficienciesChanged: (String, String, [String]) -> Void
    let onResultMathMindsetTogglesChanged: (String, String, [String]) -> Void
    let onResultNextStepGoalsChanged: (String, String, [String]) -> Void
    let onGenerate: () -> Void
    let onManualEditChanged: (String, String, String) -> Void
    let onLockChanged: (String, String, Bool) -> Void
    let onApproveReportForExport: (String, String) -> Void
    let onAIPolishReport: (String, String) -> Void
    let onAIToneAdjustReport: (String, String) -> Void
    let onAIDraftFromEvidenceReport: (String, String) -> Void
    let onBulkAIPolishReports: () -> Void
    let onCancelBulkAIPolish: () -> Void
    let onAcceptAIRevision: (String, String) -> Void
    let onRejectAIRevision: (String, String) -> Void
    let onLocalSafetyCheck: (String, String) -> Void
    let onValidationWarningsReviewed: (String, String) -> Void
    let onAICritiqueReport: (String, String) -> Void
    let onAIToneProfileChanged: (AIToneProfile) -> Void
    let onAITargetLengthChanged: (ReportLengthTarget) -> Void
    let onAICustomInstructionChanged: (String) -> Void
    let onAIForbiddenMentionsChanged: ([String]) -> Void
    let onAIRequiredMentionsChanged: ([String]) -> Void
    let onAISettingsResetBalanced: () -> Void
    let onReportAIToneProfileChanged: (String, String, AIToneProfile) -> Void
    let onReportAITargetLengthChanged: (String, String, ReportLengthTarget) -> Void
    let onReportAICustomInstructionChanged: (String, String, String) -> Void
    let onReportAIForbiddenMentionsChanged: (String, String, [String]) -> Void
    let onReportAIRequiredMentionsChanged: (String, String, [String]) -> Void
    let onReportAIOptionsSavedAsProjectDefaults: (String, String) -> Void
    let onReportAIOptionsReset: (String, String) -> Void
    let onImportRoster: () -> Void
    let onImportResults: () -> Void
    let onPrepareBackup: () -> Void
    let onPrepareExport: (ImportExportFormat) -> Void
    let onSavePreparedFile: () -> Void
    let onSharePreparedFile: () -> Void
    let onDismissPreparedFile: () -> Void
    let onDismissStatus: () -> Void
    let onConfirmImport: () -> Void
    let onCancelImportPreview: () -> Void

    @State private var activeStudentEditorRoute: StudentEditorRoute?
    @State private var taskFocus: WorklistTaskFocus = .all

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StationeryPageHeader(
                        project?.metadata.name ?? "Work list",
                        subtitle: project == nil ? "Your workflow hub" : "Local state, progress, and recovery prompts"
                    )
                }
                .worklistStationeryChromeRow()

                workflowStatusSection

                if let pendingImport {
                    ImportPreviewSection(
                        preview: pendingImport,
                        isSaving: isWorkflowBusy,
                        onConfirm: onConfirmImport,
                        onCancel: onCancelImportPreview
                    )
                    .worklistStationerySectionRows()
                }

                if let project {
                    taskFocusSection
                    if taskFocus.showsSetup {
                    ProjectMetadataSection(
                        project: project,
                        onNameChanged: onProjectNameChanged,
                        onTermChanged: onProjectTermChanged,
                        onYearLevelChanged: onProjectYearLevelChanged,
                        onUseFirstNameOnlyChanged: onUseFirstNameOnlyChanged,
                        onSave: onSave,
                        onDeleteProject: onDeleteProject,
                        isDisabled: isEditingLocked,
                        deleteDisabledReason: projectDeleteDisabledReason
                    )
                    .worklistStationerySectionRows()
                    RosterSection(
                        project: project,
                        importState: rosterImportState,
                        onAddStudent: onAddStudent,
                        onDeleteStudent: onDeleteStudent,
                        onFirstNameChanged: onStudentFirstNameChanged,
                        onLastNameChanged: onStudentLastNameChanged,
                        onYearChanged: onStudentYearChanged,
                        onGenderChanged: onStudentGenderChanged,
                        onPronounsChanged: onStudentPronounsChanged,
                        onInternalNoteChanged: onStudentInternalNoteChanged,
                        onAttitudeDescriptorChanged: onStudentAttitudeDescriptorChanged,
                        onImportRoster: onImportRoster,
                        onOpenStudentEditor: { activeStudentEditorRoute = StudentEditorRoute(studentId: $0) },
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
                    SubjectsSection(
                        project: project,
                        onSubjectToggled: onSubjectToggled,
                        onSelectAll: onSelectAllSubjects,
                        onDeselectAll: onDeselectAllSubjects,
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
                    }
                    if taskFocus.showsResults {
                    ResultsSection(
                        project: project,
                        readiness: readiness,
                        importState: resultsImportState,
                        onAchievementChanged: onAchievementChanged,
                        onFocusChanged: onFocusChanged,
                        onEvidenceChanged: onResultEvidenceChanged,
                        onTextTypeChanged: onResultTextTypeChanged,
                        onLearningContextChanged: onResultLearningContextChanged,
                        onReportEmphasisNoteChanged: onResultReportEmphasisNoteChanged,
                        onFlagChanged: onResultFlagChanged,
                        onEnglishFocusTagsChanged: onResultEnglishFocusTagsChanged,
                        onMathProficienciesChanged: onResultMathProficienciesChanged,
                        onMathMindsetTogglesChanged: onResultMathMindsetTogglesChanged,
                        onNextStepGoalsChanged: onResultNextStepGoalsChanged,
                        onImportResults: onImportResults,
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
                    }
                    if taskFocus.showsDrafts {
                    ReportsSection(
                        project: project,
                        readiness: readiness,
                        datasetStatus: datasetStatus,
                        aiAvailabilityStatus: aiAvailabilityStatus,
                        operationStatus: operationStatus,
                        pendingAIRevision: pendingAIRevision,
                        pendingAIRevisions: pendingAIRevisions,
                        isBulkAIRevisionRunning: isBulkAIRevisionRunning,
                        latestReportCheck: latestReportCheck,
                        isGenerating: isGeneratingReports,
                        onGenerate: onGenerate,
                        onManualEditChanged: onManualEditChanged,
                        onLockChanged: onLockChanged,
                        onApproveReportForExport: onApproveReportForExport,
                        onAIPolishReport: onAIPolishReport,
                        onAIToneAdjustReport: onAIToneAdjustReport,
                        onAIDraftFromEvidenceReport: onAIDraftFromEvidenceReport,
                        onBulkAIPolishReports: onBulkAIPolishReports,
                        onCancelBulkAIPolish: onCancelBulkAIPolish,
                        onAcceptAIRevision: onAcceptAIRevision,
                        onRejectAIRevision: onRejectAIRevision,
                        onLocalSafetyCheck: onLocalSafetyCheck,
                        onValidationWarningsReviewed: onValidationWarningsReviewed,
                        onAICritiqueReport: onAICritiqueReport,
                        onAIToneProfileChanged: onAIToneProfileChanged,
                        onAITargetLengthChanged: onAITargetLengthChanged,
                        onAICustomInstructionChanged: onAICustomInstructionChanged,
                        onAIForbiddenMentionsChanged: onAIForbiddenMentionsChanged,
                        onAIRequiredMentionsChanged: onAIRequiredMentionsChanged,
                        onAISettingsResetBalanced: onAISettingsResetBalanced,
                        onReportAIToneProfileChanged: onReportAIToneProfileChanged,
                        onReportAITargetLengthChanged: onReportAITargetLengthChanged,
                        onReportAICustomInstructionChanged: onReportAICustomInstructionChanged,
                        onReportAIForbiddenMentionsChanged: onReportAIForbiddenMentionsChanged,
                        onReportAIRequiredMentionsChanged: onReportAIRequiredMentionsChanged,
                        onReportAIOptionsSavedAsProjectDefaults: onReportAIOptionsSavedAsProjectDefaults,
                        onReportAIOptionsReset: onReportAIOptionsReset,
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
                    }
                    if taskFocus.showsFiles {
                    ReportExportsSection(
                        readiness: readiness,
                        records: lastPreparedFiles,
                        onPrepareExport: onPrepareExport,
                        isDisabled: isEditingLocked || hasUnsavedChanges,
                        disabledReason: exportDisabledReason
                    )
                    .worklistStationerySectionRows()
                    BackupSection(
                        record: lastPreparedFiles[.backupJSON],
                        onPrepareBackup: onPrepareBackup,
                        isDisabled: isEditingLocked || hasUnsavedChanges,
                        disabledReason: backupDisabledReason
                    )
                    .worklistStationerySectionRows()
                    PreparedFileSection(
                        preparedFile: hasUnsavedChanges ? nil : preparedFile,
                        hasHiddenStalePreparedFile: hasUnsavedChanges && preparedFile != nil,
                        onSavePreparedFile: onSavePreparedFile,
                        onSharePreparedFile: onSharePreparedFile,
                        onDismissPreparedFile: onDismissPreparedFile,
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
                    }
                } else if pendingImport == nil {
                    Section {
                        StationeryEmptyState(
                            systemImage: "folder.badge.questionmark",
                            title: "No project open yet",
                            message: "Create or open a local project from Projects to manage roster, subjects, results, drafts, reports, and backups.",
                            primaryActionTitle: "Go to Projects",
                            primaryAction: onGoToProjects
                        )
                    }
                    .worklistStationeryChromeRow()
                }
            }
            .commenterGroupedListStyle()
            .scrollIndicators(.visible)
            .scrollContentBackground(.hidden)
            .background(worklistStationeryBackground)
            .navigationTitle(project?.metadata.name ?? "Work list")
            .commenterLargeNavigationTitle()
            .accessibilityIdentifier("worklist-list")
            .navigationDestination(item: $activeStudentEditorRoute) { route in
                studentEditorDestination(for: route)
            }
        }
        .accessibilityIdentifier("worklist-page")
    }

    @ViewBuilder private func studentEditorDestination(for route: StudentEditorRoute) -> some View {
        if let student = project?.roster.first(where: { $0.id == route.studentId }) {
            StudentEditorView(
                student: student,
                isDisabled: isEditingLocked,
                onFirstNameChanged: { onStudentFirstNameChanged(route.studentId, $0) },
                onLastNameChanged: { onStudentLastNameChanged(route.studentId, $0) },
                onYearChanged: { onStudentYearChanged(route.studentId, $0) },
                onGenderChanged: { onStudentGenderChanged(route.studentId, $0) },
                onPronounsChanged: { onStudentPronounsChanged(route.studentId, $0) },
                onInternalNoteChanged: { onStudentInternalNoteChanged(route.studentId, $0) },
                onAttitudeDescriptorChanged: { onStudentAttitudeDescriptorChanged(route.studentId, $0) },
                onDelete: {
                    onDeleteStudent(route.studentId)
                    activeStudentEditorRoute = nil
                }
            )
        } else {
            StudentEditorUnavailableView(studentId: route.studentId)
        }
    }

    private var workflowStatusSection: some View {
        Section {
            NotebookCard(showsPaperclip: project != nil) {
                VStack(alignment: .leading, spacing: 12) {
                    OperationStatusView(status: operationStatus, onDismiss: onDismissStatus)
                    if let readiness, readiness.expected > 0 {
                        LabeledContent("Export ready", value: "\(readiness.ready) of \(readiness.expected)")
                            .accessibilityLabel("Export ready \(readiness.ready) of \(readiness.expected)")
                    } else if project != nil {
                        StatusChip("Add students to get started", systemImage: "person.badge.plus", tone: .neutral)
                    }
                    if case .saving = status {
                        ProgressView("Saving and verifying project")
                    }
                    if case .deleting = status {
                        ProgressView("Creating recovery snapshot and deleting project")
                    }
                    if case .generating = status {
                        ProgressView("Generating deterministic draft comments")
                    }
                    if case .importing = status {
                        ProgressView("Validating import")
                    }
                    if case .preparingFile = status {
                        ProgressView("Preparing and verifying file")
                    }
                    if isWorkflowBusy {
                        Text("Editing and file actions are paused until the current operation finishes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if pendingImport != nil, !isWorkflowBusy {
                        Text("A validated import is waiting for confirmation. Confirm or cancel it before editing this project.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if hasUnsavedChanges {
                        Text("Save the project before preparing backups or exports so the file reflects verified local state.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(action: onSave) {
                            Label("Save Project", systemImage: "square.and.arrow.down")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isEditingLocked)
                    }
                }
            }
        } header: {
            CommenterSectionHeader("Workflow", detail: "Local state, progress, and recovery prompts")
        }
        .worklistStationeryChromeRow()
    }

    private var taskFocusSection: some View {
        Section {
            NotebookCard {
                Picker("Task focus", selection: $taskFocus) {
                    ForEach(WorklistTaskFocus.allCases) { focus in
                        Label(focus.title, systemImage: focus.systemImage).tag(focus)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isEditingLocked)
                .accessibilityIdentifier("worklist-task-focus-picker")
                Text(taskFocus.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            CommenterSectionHeader("Task focus", detail: "Show all workflow areas or narrow the list to the current job")
        }
        .worklistStationeryChromeRow()
    }

    private var worklistStationeryBackground: some View {
        CommenterStationeryTheme.Colors.paperBackground
            .ignoresSafeArea()
            .overlay(StationeryPaperTexture().ignoresSafeArea())
    }

    private var isEditingLocked: Bool {
        isWorkflowBusy || pendingImport != nil
    }

    private var isWorkflowBusy: Bool {
        isLongRunningProjectOperation(status)
    }

    private var hasUnsavedChanges: Bool {
        if hasUnsavedProjectChanges {
            return true
        }
        if case .dirty = operationStatus {
            return true
        }
        return false
    }

    private var isGeneratingReports: Bool {
        if case .generating = status { return true }
        return false
    }

    private var exportDisabledReason: String? {
        if let pendingImport {
            return "\(pendingImport.title) is waiting. Confirm or cancel the import before preparing report files."
        }
        if isWorkflowBusy {
            return "Wait for the current local operation to finish before preparing report files."
        }
        if hasUnsavedChanges {
            return "Save current changes before preparing report files so exported files reflect verified local state."
        }
        return nil
    }

    private var backupDisabledReason: String? {
        if let pendingImport {
            return "\(pendingImport.title) is waiting. Confirm or cancel the import before preparing a backup."
        }
        if isWorkflowBusy {
            return "Wait for the current local operation to finish before preparing a backup."
        }
        if hasUnsavedChanges {
            return "Save current changes before preparing a backup so it reflects verified local state."
        }
        return nil
    }

    private var projectDeleteDisabledReason: String? {
        if let pendingImport {
            return "\(pendingImport.title) is waiting. Confirm or cancel the import before deleting this project."
        }
        if isWorkflowBusy {
            return "Wait for the current local operation to finish before deleting this project."
        }
        if hasUnsavedChanges {
            return "Save or reopen the project before deleting it so the recovery snapshot reflects verified local storage."
        }
        return nil
    }
}

private enum WorklistTaskFocus: String, CaseIterable, Identifiable {
    case all
    case setup
    case results
    case drafts
    case files

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .setup: return "Setup"
        case .results: return "Results"
        case .drafts: return "Drafts"
        case .files: return "Files"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "rectangle.grid.1x2"
        case .setup: return "person.2"
        case .results: return "checklist"
        case .drafts: return "doc.text"
        case .files: return "square.and.arrow.up"
        }
    }

    var detail: String {
        switch self {
        case .all:
            return "Showing setup, results, drafts, exports, backup, and prepared files."
        case .setup:
            return "Showing project details, roster, and subjects."
        case .results:
            return "Showing result import and focused result entry."
        case .drafts:
            return "Showing deterministic draft generation, review, and AI review tools."
        case .files:
            return "Showing verified report export, backup, and prepared-file actions."
        }
    }

    var showsSetup: Bool { self == .all || self == .setup }
    var showsResults: Bool { self == .all || self == .results }
    var showsDrafts: Bool { self == .all || self == .drafts }
    var showsFiles: Bool { self == .all || self == .files }
}

private extension View {
    func worklistStationeryChromeRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 10, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    func worklistStationerySectionRows() -> some View {
        self
            .listRowBackground(CommenterStationeryTheme.Colors.paperSurface)
            .listRowSeparatorTint(CommenterStationeryTheme.Colors.paperLine)
    }
}
