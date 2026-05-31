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
                    Button(action: onImportBackup) {
                        Label("Import Project Backup", systemImage: "tray.and.arrow.down")
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
                        }
                    }
                }
            }
            .navigationTitle("Projects")
        }
    }

    @ViewBuilder
    private var storageStatusContent: some View {
        switch status {
        case .notLoaded, .loading:
            ProgressView("Checking local project storage")
        case .creating, .loadingProject, .saving, .preparingFile, .importing, .generating:
            ProgressView(message)
        case .loaded:
            LabeledContent("Storage", value: message)
        case let .failed(message):
            UnavailableFeatureNotice(title: "Project storage unavailable", message: message)
        }
    }
}
