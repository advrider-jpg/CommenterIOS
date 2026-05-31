import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct AppView: View {
    private let store: StoreOf<AppFeature>

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
                    onCreateProject: { viewStore.send(.createProjectTapped) }
                )
                    .tabItem { Label("Projects", systemImage: "folder") }
                    .tag(AppFeature.Tab.projects)

                WorklistRootView(message: viewStore.importExportMessage)
                    .tabItem { Label("Worklist", systemImage: "checklist") }
                    .tag(AppFeature.Tab.worklist)

                SupportRootView(datasetStatus: viewStore.datasetStatus)
                    .tabItem { Label("Support", systemImage: "questionmark.circle") }
                    .tag(AppFeature.Tab.support)
            }
            .task { await viewStore.send(.task).finish() }
        }
    }
}

private struct ProjectsRootView: View {
    let message: String
    let status: AppFeature.ProjectStorageStatus
    let projects: [ProjectSummary]
    let onCreateProject: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    switch status {
                    case .notLoaded, .loading:
                        ProgressView("Checking local project storage")
                    case .loaded:
                        LabeledContent("Storage", value: message)
                    case .creating:
                        ProgressView(message)
                    case let .failed(message):
                        UnavailableFeatureNotice(title: "Project storage unavailable", message: message)
                    }
                }
                Section {
                    Button("Create Project", action: onCreateProject)
                        .disabled(!canCreateProject)
                    Button("Import Project Backup") {}
                        .disabled(true)
                }
                Section("Saved Projects") {
                    if projects.isEmpty {
                        Text("No saved projects on this device.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(projects) { project in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.headline)
                                Text(project.term)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let revision = project.revision {
                                    Text("Revision \(revision)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
        }
    }

    private var canCreateProject: Bool {
        if case .loaded = status { return true }
        return false
    }
}

private struct WorklistRootView: View {
    let message: String

    var body: some View {
        NavigationStack {
            List {
                Section {
                    UnavailableFeatureNotice(
                        title: "Teacher workflow not ready",
                        message: message
                    )
                }
                Section("Required MVP formats") {
                    Label("CSV roster and results import", systemImage: "tablecells")
                    Label("XLSX roster and results import/export", systemImage: "doc")
                    Label("Legacy XLS roster and results import/export", systemImage: "doc")
                    Label("DOCX report export", systemImage: "doc.richtext")
                    Label("Backup JSON import/export", systemImage: "externaldrive")
                }
            }
            .navigationTitle("Worklist")
        }
    }
}

private struct SupportRootView: View {
    let datasetStatus: AppFeature.DatasetStatus

    var body: some View {
        NavigationStack {
            List {
                Section("Production Dataset") {
                    switch datasetStatus {
                    case .notLoaded, .loading:
                        ProgressView("Checking bundled comment engine")
                    case let .loaded(snapshot):
                        LabeledContent("Status", value: "Bundled dataset loaded")
                        LabeledContent("Checks", value: "Basic structural checks passed")
                        LabeledContent("Subjects", value: "\(snapshot.subjectCount)")
                        LabeledContent("Components", value: "\(snapshot.componentCount)")
                        LabeledContent("Recipes", value: "\(snapshot.recipeCount)")
                        LabeledContent("Assembled variants", value: "\(snapshot.assembledVariantCount)")
                        LabeledContent("Uniqueness rules", value: "\(snapshot.uniquenessGuardCount)")
                        if !snapshot.warnings.isEmpty {
                            ForEach(snapshot.warnings, id: \.self) { warning in
                                Text(warning)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        LabeledContent("Bundled hash", value: snapshot.hash)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .accessibilityLabel("Dataset hash \(snapshot.hash)")
                        LabeledContent("Normalized source hash", value: snapshot.normalizedSourceHash)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .accessibilityLabel("Normalized source hash \(snapshot.normalizedSourceHash)")
                    case let .failed(message):
                        UnavailableFeatureNotice(title: "Dataset blocked", message: message)
                    }
                }

                Section("Privacy") {
                    Text("CommenterIOS is local-only. Accounts, cloud sync, analytics, telemetry, remote AI, and backend project persistence are outside the MVP product shape.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Support")
        }
    }
}
