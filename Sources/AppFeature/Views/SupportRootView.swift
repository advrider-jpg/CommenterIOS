import CommentEngine
import CommenterDomain
import DesignSystem
import SwiftUI

struct SupportRootView: View {
    let datasetStatus: AppFeature.DatasetStatus
    let projectStorageStatus: AppFeature.ProjectStorageStatus
    let projectStorageMessage: String
    let projectCount: Int
    let selectedProject: Project?
    let readiness: ProjectReadiness?
    let preparedFile: AppFeature.PreparedFile?

    var body: some View {
        NavigationStack {
            List {
                Section("Production Dataset") {
                    datasetStatusContent
                }

                Section("Local Projects") {
                    LabeledContent("Storage", value: projectStorageStatusLabel)
                    Text(projectStorageMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LabeledContent("Projects on device", value: "\(projectCount)")
                }

                Section("Open Project") {
                    if let selectedProject {
                        LabeledContent("Project", value: selectedProject.metadata.name)
                        if let readiness {
                            LabeledContent("Export ready", value: "\(readiness.ready) of \(readiness.expected)")
                        } else {
                            LabeledContent("Export ready", value: "Not checked")
                        }
                    } else {
                        LabeledContent("Project", value: "None open")
                        LabeledContent("Export ready", value: "No project selected")
                    }
                }

                Section("Prepared File") {
                    if let preparedFile {
                        LabeledContent("Ready file", value: preparedFile.url.lastPathComponent)
                        Text(preparedFile.label)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        LabeledContent("Ready file", value: "None")
                    }
                }

                Section("Backup and Recovery") {
                    Text("Use Prepare Backup JSON for a user-owned export copy. Project saves, backup imports, and project deletion create local recovery snapshots before replacing or removing verified project storage.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Recovery snapshots remain local in the app support folder; the MVP does not upload or synchronize them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Release Diagnostics") {
                    LabeledContent("Network services", value: "Not configured")
                    LabeledContent("Analytics and telemetry", value: "Not configured")
                    LabeledContent("Native document workflows", value: "Import, export, and share")
                    Text("File success is only recorded after native completion callbacks report a saved export or completed share.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Privacy") {
                    Text("CommenterIOS is local-only. Accounts, cloud sync, analytics, telemetry, remote AI, and backend project persistence are outside the MVP product shape.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .navigationTitle("Support")
            .accessibilityIdentifier("support-page")
        }
    }

    @ViewBuilder
    private var datasetStatusContent: some View {
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

    private var projectStorageStatusLabel: String {
        switch projectStorageStatus {
        case .notLoaded:
            "Not loaded"
        case .loading:
            "Loading"
        case .loaded:
            "Loaded"
        case .creating:
            "Creating project"
        case .loadingProject:
            "Loading project"
        case .saving:
            "Saving"
        case .deleting:
            "Deleting project"
        case .preparingFile:
            "Preparing file"
        case .importing:
            "Importing"
        case .generating:
            "Generating reports"
        case .failed:
            "Failed"
        }
    }
}
