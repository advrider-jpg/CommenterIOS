import CommenterDomain
import DesignSystem
import SwiftUI

struct ProjectsRootView: View {
    let message: String
    let status: AppFeature.ProjectStorageStatus
    let projects: [ProjectSummary]
    let operationStatus: AppFeature.OperationStatus
    let onCreateProject: () -> Void
    let onOpenProject: (String) -> Void
    let onImportBackup: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OperationStatusView(status: operationStatus)
                    storageStatusContent
                }

                Section {
                    Button(action: onCreateProject) {
                        Label("Create Project", systemImage: "plus")
                    }
                    .disabled(!canStartProjectStorageAction)
                    .accessibilityIdentifier("create-project-button")
                    Button(action: onImportBackup) {
                        Label("Import Project Backup", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(!canStartProjectStorageAction)
                    if !canStartProjectStorageAction {
                        Text(projectActionUnavailableMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Saved Projects") {
                    if projects.isEmpty {
                        Text("No saved projects on this device.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(projects) { project in
                            Button {
                                onOpenProject(project.id)
                            } label: {
                                ProjectSummaryCard(
                                    name: project.name,
                                    term: project.term,
                                    revision: project.revision
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canStartProjectStorageAction)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .accessibilityIdentifier("projects-page")
        }
    }

    private var canStartProjectStorageAction: Bool {
        if case .loaded = status {
            return true
        }
        return false
    }

    private var projectActionUnavailableMessage: String {
        switch status {
        case .notLoaded, .loading:
            return "Local project storage is still being checked."
        case .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            return "Finish the current local operation before starting another project action."
        case .failed:
            return "Project actions are unavailable until local storage is available."
        case .loaded:
            return ""
        }
    }

    @ViewBuilder
    private var storageStatusContent: some View {
        switch status {
        case .notLoaded, .loading:
            ProgressView("Checking local project storage")
        case .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            ProgressView(message)
        case .loaded:
            LabeledContent("Storage", value: message)
        case let .failed(message):
            UnavailableFeatureNotice(title: "Project storage unavailable", message: message)
        }
    }
}
