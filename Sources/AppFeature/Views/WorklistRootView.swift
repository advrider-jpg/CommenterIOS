import CommentEngine
import CommenterDomain
import CommenterImportExport
import DesignSystem
import SwiftUI

struct WorklistRootView: View {
    let project: Project?
    let readiness: ProjectReadiness?
    let status: AppFeature.ProjectStorageStatus
    let operationStatus: AppFeature.OperationStatus
    let hasUnsavedProjectChanges: Bool
    let preparedFile: AppFeature.PreparedFile?
    let pendingImport: AppFeature.PendingImport?
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
                    ReportsSection(
                        project: project,
                        readiness: readiness,
                        datasetStatus: datasetStatus,
                        isGenerating: isGeneratingReports,
                        onGenerate: onGenerate,
                        onManualEditChanged: onManualEditChanged,
                        onLockChanged: onLockChanged,
                        isDisabled: isEditingLocked
                    )
                    .worklistStationerySectionRows()
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
            .safeAreaInset(edge: .bottom) {
                DeskEdgeDecoration()
                    .frame(height: 76)
                    .accessibilityHidden(true)
            }
            .navigationTitle(project?.metadata.name ?? "Work list")
            .commenterLargeNavigationTitle()
            .accessibilityIdentifier("worklist-list")
        }
        .accessibilityIdentifier("worklist-page")
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
                    }
                }
            }
        } header: {
            CommenterSectionHeader("Workflow", detail: "Local state, progress, and recovery prompts")
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
