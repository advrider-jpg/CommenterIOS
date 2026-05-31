import CommentEngine
import CommenterDomain
import CommenterImportExport
import SwiftUI

struct WorklistRootView: View {
    let project: Project?
    let readiness: ProjectReadiness?
    let status: AppFeature.ProjectStorageStatus
    let operationStatus: AppFeature.OperationStatus
    let preparedFile: AppFeature.PreparedFile?
    let pendingImport: AppFeature.PendingImport?
    let onProjectNameChanged: (String) -> Void
    let onProjectTermChanged: (String) -> Void
    let onProjectYearLevelChanged: (ProjectYearLevel) -> Void
    let onUseFirstNameOnlyChanged: (Bool) -> Void
    let onSave: () -> Void
    let onAddStudent: () -> Void
    let onDeleteStudent: (String) -> Void
    let onStudentFirstNameChanged: (String, String) -> Void
    let onStudentLastNameChanged: (String, String) -> Void
    let onStudentYearChanged: (String, StudentYearLevel) -> Void
    let onSubjectToggled: (String) -> Void
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
    let onDismissPreparedFile: () -> Void
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
                        isDisabled: isEditingLocked
                    )
                    RosterSection(
                        project: project,
                        onAddStudent: onAddStudent,
                        onDeleteStudent: onDeleteStudent,
                        onFirstNameChanged: onStudentFirstNameChanged,
                        onLastNameChanged: onStudentLastNameChanged,
                        onYearChanged: onStudentYearChanged,
                        onImportRoster: onImportRoster,
                        isDisabled: isEditingLocked
                    )
                    SubjectsSection(project: project, onSubjectToggled: onSubjectToggled, isDisabled: isEditingLocked)
                    ResultsSection(
                        project: project,
                        readiness: readiness,
                        onAchievementChanged: onAchievementChanged,
                        onFocusChanged: onFocusChanged,
                        onImportResults: onImportResults,
                        isDisabled: isEditingLocked
                    )
                    ReportsSection(
                        project: project,
                        onGenerate: onGenerate,
                        onManualEditChanged: onManualEditChanged,
                        onLockChanged: onLockChanged,
                        isDisabled: isEditingLocked
                    )
                    ExportSection(
                        preparedFile: hasUnsavedChanges ? nil : preparedFile,
                        hasHiddenStalePreparedFile: hasUnsavedChanges && preparedFile != nil,
                        readiness: readiness,
                        onPrepareBackup: onPrepareBackup,
                        onPrepareExport: onPrepareExport,
                        onSavePreparedFile: onSavePreparedFile,
                        onDismissPreparedFile: onDismissPreparedFile,
                        isDisabled: isEditingLocked || hasUnsavedChanges,
                        disabledReason: exportDisabledReason
                    )
                } else if pendingImport == nil {
                    Section {
                        ContentUnavailableView(
                            "No Project Open",
                            systemImage: "folder",
                            description: Text("Create or open a local project from Projects.")
                        )
                    }
                }
            }
            .navigationTitle(project?.metadata.name ?? "Worklist")
        }
    }

    private var workflowStatusSection: some View {
        Section {
            OperationStatusView(status: operationStatus)
            if let readiness {
                LabeledContent("Export ready", value: "\(readiness.ready) of \(readiness.expected)")
            }
            if case .saving = status {
                ProgressView("Saving and verifying project")
            }
            if case .generating = status {
                ProgressView("Generating and saving reports")
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

    private var isEditingLocked: Bool {
        isWorkflowBusy || pendingImport != nil
    }

    private var isWorkflowBusy: Bool {
        switch status {
        case .creating, .loadingProject, .saving, .preparingFile, .importing, .generating:
            return true
        case .notLoaded, .loading, .loaded, .failed:
            return false
        }
    }

    private var hasUnsavedChanges: Bool {
        if case .dirty = operationStatus {
            return true
        }
        return false
    }

    private var exportDisabledReason: String? {
        if let pendingImport {
            return "\(pendingImport.title) is waiting. Confirm or cancel the import before preparing backup or report files."
        }
        if isWorkflowBusy {
            return "Wait for the current local operation to finish before preparing backup or report files."
        }
        if hasUnsavedChanges {
            return "Save current changes before preparing backup or report files so exported files reflect verified local state."
        }
        return nil
    }
}
