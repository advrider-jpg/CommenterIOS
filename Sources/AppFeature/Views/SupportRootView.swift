import CommentEngine
import CommenterDomain
import CommenterImportExport
import DesignSystem
import SwiftUI

struct SupportRootView: View {
    let state: AppFeature.State
    let onCopyDiagnostics: () -> Void
    let onDismissStatus: () -> Void

    private let buildInfo = AppBuildInfo.current()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    OperationStatusView(status: state.operationStatus, onDismiss: onDismissStatus)
                    Button(action: onCopyDiagnostics) {
                        CommenterActionRow(
                            title: "Copy diagnostics to clipboard",
                            subtitle: "Copies app, dataset, storage, project, readiness, and privacy details for a support request.",
                            systemImage: "doc.on.doc",
                            isEnabled: canCopyDiagnostics,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCopyDiagnostics)
                } header: {
                    CommenterSectionHeader("Support actions")
                }

                Section {
                    datasetStatusContent
                } header: {
                    CommenterSectionHeader("Production dataset", detail: "Bundled deterministic comment data")
                }

                Section {
                    LabeledContent("App", value: buildInfo.displayName)
                    LabeledContent("Version", value: buildInfo.version)
                    LabeledContent("Build", value: buildInfo.build)
                    LabeledContent("Network services", value: "Not configured")
                    LabeledContent("Analytics and telemetry", value: "Not configured")
                } header: {
                    CommenterSectionHeader("App build")
                }

                Section {
                    LabeledContent("Storage", value: projectStorageStatusDescription(state.projectStorageStatus))
                        .accessibilityIdentifier("project-storage-status")
                    Text(state.projectStorageMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LabeledContent("Projects on device", value: CommenterFormatters.integer(state.projects.count))
                    LabeledContent("Current operation", value: operationStatusLabel)
                } header: {
                    CommenterSectionHeader("Storage diagnostics", detail: "Local-only project index and file workflow state")
                }

                Section {
                    if let project = state.selectedProject {
                        LabeledContent("Project", value: project.metadata.name)
                        LabeledContent("Project ID", value: project.metadata.id)
                        LabeledContent("Term", value: project.metadata.term)
                        LabeledContent("Year level", value: projectYearLabel(project.metadata.yearLevel))
                        LabeledContent("Last saved", value: CommenterFormatters.timestamp(project.metadata.persistence?.savedAt))
                        LabeledContent("Revision", value: project.metadata.persistence?.revision.map { String($0) } ?? "Not yet recorded")
                        if let fingerprint = project.metadata.persistence?.fingerprint {
                            HashBlock(title: "Project fingerprint", hash: fingerprint)
                        }
                        LabeledContent("Roster", value: CommenterFormatters.integer(project.roster.count))
                        LabeledContent("Selected subjects", value: CommenterFormatters.integer(project.metadata.selectedSubjects.count))
                        LabeledContent("Results", value: CommenterFormatters.integer(project.results.count))
                        LabeledContent("Draft reports", value: CommenterFormatters.integer(project.reports.count))
                        if let readiness = state.selectedProjectReadiness {
                            LabeledContent("Export readiness", value: "\(readiness.ready) of \(readiness.expected)")
                            if !readiness.blocked.isEmpty {
                                DisclosureGroup("Blocked readiness details") {
                                    ForEach(readiness.blocked.indices, id: \.self) { index in
                                        Text(readiness.blocked[index].message)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    } else {
                        LabeledContent("Project", value: "None open")
                        Text("Open a project to include project-specific storage, fingerprint, roster, result, and export-readiness diagnostics.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    CommenterSectionHeader("Open project diagnostics")
                }

                Section {
                    if state.lastPreparedFiles.isEmpty {
                        LabeledContent("Prepared files", value: "None yet")
                    } else {
                        ForEach(ImportExportFormat.preparationDisplayOrder, id: \.self) { format in
                            if let record = state.lastPreparedFiles[format] {
                                VStack(alignment: .leading, spacing: 4) {
                                    LabeledContent(format.supportLabel, value: record.filename)
                                        .accessibilityIdentifier(format == .docx ? "support-ready-file" : "support-ready-file-\(format.rawValue)")
                                    Text("Prepared: \(CommenterFormatters.timestamp(record.preparedAtMilliseconds))")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    CommenterSectionHeader("Prepared files")
                }

                Section {
                    Text("Project names, roster data, results, draft comments, backups, and report files stay on this device unless you choose a native file export or share destination.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("CommenterIOS does not configure accounts, cloud sync, analytics, telemetry, remote AI, or backend project persistence in this MVP.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    CommenterSectionHeader("Privacy guidance")
                }

                Section {
                    Text("Prepare Backup JSON before device migration, destructive edits, deletion, or support troubleshooting. Deleting or replacing a verified local project attempts a local recovery snapshot first.")
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onCopyDiagnostics) {
                        CommenterActionRow(
                            title: "Report a bug: copy diagnostics",
                            subtitle: "Paste the copied diagnostic block into your support email or issue tracker.",
                            systemImage: "envelope",
                            isEnabled: canCopyDiagnostics,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCopyDiagnostics)
                } header: {
                    CommenterSectionHeader("Backup and feedback")
                }
            }
            .commenterGroupedListStyle()
            .scrollIndicators(.visible)
            .background(CommenterColors.groupedBackground)
            .navigationTitle("Support")
            .commenterLargeNavigationTitle()
            .accessibilityIdentifier("support-page")
        }
    }

    @ViewBuilder
    private var datasetStatusContent: some View {
        switch state.datasetStatus {
        case .notLoaded, .loading:
            ProgressView("Checking bundled comment engine")
        case let .loaded(snapshot):
            LabeledContent("Status", value: "Bundled dataset loaded")
                .accessibilityIdentifier("dataset-loaded-status")
            if snapshot.hash == snapshot.normalizedSourceHash {
                StatusChip("Verified match", systemImage: "checkmark.seal", tone: .success)
                Text("The bundled hash matches the normalized source hash, so the packaged dataset and normalized source data identify the same production data.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                StatusChip("Hash mismatch", systemImage: "exclamationmark.triangle", tone: .failure)
                Text("The bundled hash and normalized source hash do not match. Capture diagnostics before generating or exporting reports.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            DisclosureGroup("Structural checks passed") {
                Text("Schema version, subject count integrity, component count, recipe count, assembled variant count, and uniqueness guard count loaded without structural errors.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledContent("Last validated", value: CommenterFormatters.timestamp(snapshot.loadedAtMilliseconds))
            LabeledContent("Subjects", value: CommenterFormatters.integer(snapshot.subjectCount))
            LabeledContent("Components", value: CommenterFormatters.integer(snapshot.componentCount))
            LabeledContent("Recipes", value: CommenterFormatters.integer(snapshot.recipeCount))
            LabeledContent("Assembled variants", value: CommenterFormatters.integer(snapshot.assembledVariantCount))
            LabeledContent("Uniqueness rules", value: CommenterFormatters.integer(snapshot.uniquenessGuardCount))
            if !snapshot.warnings.isEmpty {
                DisclosureGroup("Dataset warnings") {
                    ForEach(snapshot.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HashBlock(title: "Bundled hash", hash: snapshot.hash)
            HashBlock(title: "Normalized source hash", hash: snapshot.normalizedSourceHash)
        case let .failed(message):
            UnavailableFeatureNotice(title: "Dataset blocked", message: message)
        }
    }

    private var canCopyDiagnostics: Bool {
        if case .busy = state.operationStatus { return false }
        return true
    }

    private var operationStatusLabel: String {
        switch state.operationStatus {
        case .idle:
            return "Idle"
        case .dirty:
            return "Unsaved edits"
        case .busy:
            return "Busy"
        case .saved:
            return "Saved"
        case .prepared:
            return "Prepared file ready"
        case .shared:
            return "Share completed"
        case .cancelled:
            return "Cancelled"
        case .failed:
            return "Failed"
        }
    }
}
