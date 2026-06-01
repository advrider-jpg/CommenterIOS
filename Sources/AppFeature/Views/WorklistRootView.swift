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
    let onSubjectToggled: (String) -> Void
    let onSelectAllSubjects: () -> Void
    let onDeselectAllSubjects: () -> Void
    let onAchievementChanged: (String, String, AchievementLevel?) -> Void
    let onFocusChanged: (String, String, String) -> Void
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
                workflowStatusSection

                if let pendingImport {
                    ImportPreviewSection(
                        preview: pendingImport,
                        isSaving: isWorkflowBusy,
                        onConfirm: onConfirmImport,
                        onCancel: onCancelImportPreview
                    )
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
                    RosterSection(
                        project: project,
                        importState: rosterImportState,
                        onAddStudent: onAddStudent,
                        onDeleteStudent: onDeleteStudent,
                        onFirstNameChanged: onStudentFirstNameChanged,
                        onLastNameChanged: onStudentLastNameChanged,
                        onYearChanged: onStudentYearChanged,
                        onImportRoster: onImportRoster,
                        isDisabled: isEditingLocked
                    )
                    SubjectsSection(
                        project: project,
                        onSubjectToggled: onSubjectToggled,
                        onSelectAll: onSelectAllSubjects,
                        onDeselectAll: onDeselectAllSubjects,
                        isDisabled: isEditingLocked
                    )
                    ResultsSection(
                        project: project,
                        readiness: readiness,
                        importState: resultsImportState,
                        onAchievementChanged: onAchievementChanged,
                        onFocusChanged: onFocusChanged,
                        onImportResults: onImportResults,
                        isDisabled: isEditingLocked
                    )
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
                    ReportExportsSection(
                        readiness: readiness,
                        records: lastPreparedFiles,
                        onPrepareExport: onPrepareExport,
                        isDisabled: isEditingLocked || hasUnsavedChanges,
                        disabledReason: exportDisabledReason
                    )
                    BackupSection(
                        record: lastPreparedFiles[.backupJSON],
                        onPrepareBackup: onPrepareBackup,
                        isDisabled: isEditingLocked || hasUnsavedChanges,
                        disabledReason: backupDisabledReason
                    )
                    PreparedFileSection(
                        preparedFile: hasUnsavedChanges ? nil : preparedFile,
                        hasHiddenStalePreparedFile: hasUnsavedChanges && preparedFile != nil,
                        onSavePreparedFile: onSavePreparedFile,
                        onSharePreparedFile: onSharePreparedFile,
                        onDismissPreparedFile: onDismissPreparedFile,
                        isDisabled: isEditingLocked
                    )
                } else if pendingImport == nil {
                    Section {
                        CommenterEmptyState(
                            systemImage: "folder.badge.questionmark",
                            title: "No project open",
                            message: "Create or open a local project from Projects to manage roster, subjects, results, drafts, reports, and backups.",
                            primaryActionTitle: "Go to Projects",
                            primaryAction: onGoToProjects
                        )
                    }
                }
            }
            .commenterGroupedListStyle()
            .scrollIndicators(.visible)
            .background(CommenterColors.groupedBackground)
            .navigationTitle(project?.metadata.name ?? "Work list")
            .commenterLargeNavigationTitle()
            .accessibilityIdentifier("worklist-list")
        }
        .accessibilityIdentifier("worklist-page")
    }

    private var workflowStatusSection: some View {
        Section {
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
        } header: {
            CommenterSectionHeader("Workflow", detail: "Local state, progress, and recovery prompts")
        }
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
