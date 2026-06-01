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
    let onDeleteProject: (ProjectSummary) -> Void
    let onDismissStatus: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OperationStatusView(status: operationStatus, onDismiss: onDismissStatus)
                    storageStatusContent
                } header: {
                    CommenterSectionHeader("Storage", detail: "Verified local project files on this device")
                }

                Section {
                    Button(action: onCreateProject) {
                        CommenterActionRow(
                            title: "Create Project",
                            subtitle: "Name a class, choose the year level, and start with all curriculum areas selected.",
                            systemImage: "plus.circle",
                            isEnabled: canStartProjectStorageAction
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartProjectStorageAction)
                    .accessibilityIdentifier("create-project-button")

                    Button(action: onImportBackup) {
                        CommenterActionRow(
                            title: "Import Project Backup",
                            subtitle: "Restore a verified Commenter JSON backup into local project storage.",
                            systemImage: "square.and.arrow.down",
                            isEnabled: canStartProjectStorageAction
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canStartProjectStorageAction)

                    if !canStartProjectStorageAction {
                        Text(projectActionUnavailableMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    CommenterSectionHeader("Project actions")
                }

                Section {
                    if projects.isEmpty {
                        CommenterEmptyState(
                            systemImage: "folder.badge.plus",
                            title: "No saved projects",
                            message: "Create your first local project or import a verified backup to start building a roster and report drafts.",
                            primaryActionTitle: "Create your first project",
                            isActionDisabled: !canStartProjectStorageAction,
                            primaryAction: onCreateProject
                        )
                    } else {
                        ForEach(projects) { project in
                            Button {
                                onOpenProject(project.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .font(.title3)
                                        .foregroundStyle(CommenterColors.accent)
                                        .accessibilityHidden(true)
                                    ProjectSummaryCard(
                                        name: project.name,
                                        term: project.term,
                                        revision: project.revision
                                    )
                                    Spacer(minLength: 8)
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                        .accessibilityHidden(true)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!canStartProjectStorageAction)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDeleteProject(project)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .disabled(!canStartProjectStorageAction)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    onDeleteProject(project)
                                } label: {
                                    Label("Delete Project", systemImage: "trash")
                                }
                                .disabled(!canStartProjectStorageAction)
                            }
                        }
                    }
                } header: {
                    CommenterSectionHeader("Saved projects", detail: savedProjectsHeaderDetail)
                }
            }
            .listStyle(.insetGrouped)
            .scrollIndicators(.visible)
            .background(CommenterColors.groupedBackground)
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityIdentifier("projects-page")
        }
    }

    private var canStartProjectStorageAction: Bool {
        if case .loaded = status {
            return true
        }
        return false
    }

    private var savedProjectsHeaderDetail: String? {
        guard !projects.isEmpty else { return "Create a project to populate this list." }
        return projects.count == 1 ? "1 verified local project" : "\(projects.count) verified local projects"
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
            HStack {
                ProgressView()
                Text("Checking local project storage")
            }
            .accessibilityElement(children: .combine)
        case .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            HStack {
                ProgressView()
                Text(message)
            }
            .accessibilityElement(children: .combine)
        case .loaded:
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CommenterColors.success)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local storage ready")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    StatusChip("Verified", systemImage: "checkmark.seal", tone: .success)
                }
            }
        case let .failed(message):
            UnavailableFeatureNotice(title: "Project storage unavailable", message: message)
        }
    }
}
