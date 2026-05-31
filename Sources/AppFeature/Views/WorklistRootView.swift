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
                        onConfirm: onConfirmImport,
                        onCancel: onCancelImportPreview
                    )
                }

                if let project {
                    ProjectMetadataSection(
                        project: project,
                        onNameChanged: onProjectNameChanged,
                        onTermChanged: onProjectTermChanged,
                        onUseFirstNameOnlyChanged: onUseFirstNameOnlyChanged,
                        onSave: onSave
                    )
                    RosterSection(
                        project: project,
                        onAddStudent: onAddStudent,
                        onDeleteStudent: onDeleteStudent,
                        onFirstNameChanged: onStudentFirstNameChanged,
                        onLastNameChanged: onStudentLastNameChanged,
                        onYearChanged: onStudentYearChanged,
                        onImportRoster: onImportRoster
                    )
                    SubjectsSection(project: project, onSubjectToggled: onSubjectToggled)
                    ResultsSection(
                        project: project,
                        readiness: readiness,
                        onAchievementChanged: onAchievementChanged,
                        onFocusChanged: onFocusChanged,
                        onImportResults: onImportResults
                    )
                    ReportsSection(
                        project: project,
                        onGenerate: onGenerate,
                        onManualEditChanged: onManualEditChanged,
                        onLockChanged: onLockChanged
                    )
                    ExportSection(
                        preparedFile: preparedFile,
                        onPrepareBackup: onPrepareBackup,
                        onPrepareExport: onPrepareExport,
                        onSavePreparedFile: onSavePreparedFile,
                        onDismissPreparedFile: onDismissPreparedFile
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
        }
    }
}
