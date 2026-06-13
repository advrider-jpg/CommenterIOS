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
            StationeryScreen(scrollAccessibilityIdentifier: "projects-list") {
                StationeryPageHeader("Report Writer", subtitle: "Local report projects and verified exports")

                if hasVisibleOperationStatus {
                    NotebookCard(showsPerforation: false) {
                        OperationStatusView(status: operationStatus, onDismiss: onDismissStatus)
                    }
                }

                stationerySection(
                    title: "Storage",
                    detail: "Verified local project files on this device.",
                    tone: storageTone
                ) {
                    NotebookCard(showsPaperclip: true) {
                        storageStatusContent
                    }
                }

                stationerySection(title: "Project actions") {
                    NotebookCard {
                        VStack(spacing: 0) {
                            Button(action: onCreateProject) {
                                StationeryActionRow(
                                    title: "Create Project",
                                    subtitle: "Name a class, choose the year level, and start with all curriculum areas selected.",
                                    systemImage: "plus.circle",
                                    tone: .action,
                                    isEnabled: canStartProjectStorageAction
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canStartProjectStorageAction)
                            .accessibilityIdentifier("create-project-button")

                            Divider()
                                .padding(.vertical, 12)

                            Button(action: onImportBackup) {
                                StationeryActionRow(
                                    title: "Import Project Backup",
                                    subtitle: "Restore a verified Report Writer JSON backup into local project storage.",
                                    systemImage: "square.and.arrow.down",
                                    tone: .action,
                                    isEnabled: canStartProjectStorageAction
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!canStartProjectStorageAction)

                            if !canStartProjectStorageAction {
                                Divider()
                                    .padding(.vertical, 12)
                                Text(projectActionUnavailableMessage)
                                    .font(.footnote)
                                    .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                stationerySection(title: "Saved projects", detail: savedProjectsHeaderDetail) {
                    if projects.isEmpty {
                        emptyProjectsCard
                    } else {
                        savedProjectsCards
                    }
                }
            }
            .navigationTitle("Projects")
            .commenterInlineNavigationTitle()
        }
        .accessibilityIdentifier("projects-page")
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

    private var hasVisibleOperationStatus: Bool {
        switch operationStatus {
        case .idle:
            return false
        case .busy, .saved, .failed, .prepared, .shared, .cancelled, .dirty:
            return true
        }
    }

    private var storageTone: StationeryTone {
        switch status {
        case .loaded:
            return .local
        case .failed:
            return .failure
        case .notLoaded, .loading, .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            return .warning
        }
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
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Checking local project storage")
                        .font(.headline)
                    Text("Project actions will unlock after the local store finishes loading.")
                        .font(.subheadline)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        case .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            HStack(alignment: .center, spacing: 12) {
                ProgressView()
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentStorageOperationTitle)
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        case .loaded:
            HStack(alignment: .top, spacing: 12) {
                StatusIconBubble(systemImage: "externaldrive.fill.badge.checkmark", tone: .local)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local storage ready")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    StationeryStatusChip("Verified", systemImage: "checkmark.seal", tone: .success)
                }
            }
        case let .failed(message):
            UnavailableFeatureNotice(title: "Project storage unavailable", message: message)
        }
    }

    @ViewBuilder
    private func stationerySection<Content: View>(
        title: String,
        detail: String? = nil,
        tone: StationeryTone = .neutral,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TapeLabel(title, tone: tone)
            if let detail, !detail.isEmpty {
                HandwrittenAnnotation(detail)
                    .padding(.leading, 4)
            }
            content()
        }
    }

    private var emptyProjectsCard: some View {
        StationeryEmptyState(
            systemImage: "shippingbox",
            title: "No projects yet",
            message: "Get started by creating your first local project.",
            primaryActionTitle: "Create your first project",
            isActionDisabled: !canStartProjectStorageAction,
            primaryAction: onCreateProject
        )
    }

    private var savedProjectsCards: some View {
        VStack(spacing: 12) {
            ForEach(projects) { project in
                Button {
                    onOpenProject(project.id)
                } label: {
                    NotebookCard(showsPerforation: false) {
                        HStack(spacing: 12) {
                            StatusIconBubble(systemImage: "folder", tone: .local)
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
    }

    private var currentStorageOperationTitle: String {
        switch status {
        case .creating:
            return "Creating project"
        case .loadingProject:
            return "Opening project"
        case .saving:
            return "Saving project"
        case .deleting:
            return "Deleting project"
        case .preparingFile:
            return "Preparing file"
        case .importing:
            return "Importing backup"
        case .generating:
            return "Generating reports"
        case .notLoaded, .loading, .loaded, .failed:
            return "Local operation in progress"
        }
    }
}
