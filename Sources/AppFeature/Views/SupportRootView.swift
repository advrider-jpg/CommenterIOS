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
            StationeryScreen(scrollAccessibilityIdentifier: "support-list") {
                StationeryPageHeader("Support", subtitle: "Your support toolkit")
                supportActionsSection
                productionDatasetSection
                appBuildSection
                storageDiagnosticsSection
                openProjectDiagnosticsSection
                preparedFilesSection
                privacyGuidanceSection
                backupFeedbackSection
            }
            .navigationTitle("Support")
            .commenterInlineNavigationTitle()
        }
        .accessibilityIdentifier("support-page")
    }

    private var supportActionsSection: some View {
        supportSection("Support actions", clipped: true) {
            VStack(alignment: .leading, spacing: 14) {
                OperationStatusView(status: state.operationStatus, onDismiss: onDismissStatus)

                Button(action: onCopyDiagnostics) {
                    StationeryActionRow(
                        title: "Copy redacted diagnostics to clipboard",
                        subtitle: "Copies redacted app, dataset, storage, readiness, and privacy details for a support request.",
                        systemImage: "doc.on.doc",
                        tone: .local,
                        isEnabled: canCopyDiagnostics,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canCopyDiagnostics)
            }
        }
    }

    private var productionDatasetSection: some View {
        supportSection(
            "Production dataset",
            detail: "Bundled deterministic comment data",
            tone: datasetSectionTone,
            clipped: true
        ) {
            datasetStatusContent
        }
    }

    private var appBuildSection: some View {
        supportSection("Report Writer build") {
            VStack(alignment: .leading, spacing: 0) {
                SupportDiagnosticRow("App", value: buildInfo.displayName)
                SupportDiagnosticRow("Version", value: buildInfo.version)
                SupportDiagnosticRow("Build", value: buildInfo.build)
                SupportDiagnosticRow("Network services", value: "Not configured", valueTone: .local)
                SupportDiagnosticRow("Analytics and telemetry", value: "Not configured", valueTone: .local)
            }
        }
    }

    private var storageDiagnosticsSection: some View {
        supportSection(
            "Storage diagnostics",
            detail: "Local-only project index and file workflow state",
            tone: .local
        ) {
            VStack(alignment: .leading, spacing: 0) {
                SupportDiagnosticRow(
                    "Storage",
                    value: projectStorageStatusDescription(state.projectStorageStatus),
                    valueTone: storageStatusTone,
                    accessibilityIdentifier: "project-storage-status"
                )
                SupportBodyText(state.projectStorageMessage)
                    .padding(.vertical, 12)
                    .supportRuledDivider()
                SupportDiagnosticRow("Projects on device", value: CommenterFormatters.integer(state.projects.count))
                SupportDiagnosticRow(
                    "Invalid local records",
                    value: CommenterFormatters.integer(state.invalidProjectRecords.count),
                    valueTone: state.invalidProjectRecords.isEmpty ? .local : .warning
                )
                if !state.invalidProjectRecords.isEmpty {
                    DisclosureGroup("Invalid record details") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(state.invalidProjectRecords, id: \.id) { record in
                                SupportBodyText("\(record.id): \(record.reason)")
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    .padding(.vertical, 12)
                    .supportRuledDivider()
                }
                SupportDiagnosticRow("Current operation", value: operationStatusLabel, valueTone: operationStatusTone)
            }
        }
    }

    private var openProjectDiagnosticsSection: some View {
        supportSection("Open project diagnostics", clipped: state.selectedProject != nil) {
            VStack(alignment: .leading, spacing: 0) {
                if let project = state.selectedProject {
                    SupportDiagnosticRow("Project", value: project.metadata.name, valueTone: .local)
                    SupportDiagnosticRow("Project ID", value: project.metadata.id, valueTone: .local)
                    SupportDiagnosticRow("Term", value: project.metadata.term)
                    SupportDiagnosticRow("Year level", value: projectYearLabel(project.metadata.yearLevel))
                    SupportDiagnosticRow("Last saved", value: CommenterFormatters.timestamp(project.metadata.persistence?.savedAt))
                    SupportDiagnosticRow("Revision", value: project.metadata.persistence?.revision.map { String($0) } ?? "Not yet recorded")
                    if let fingerprint = project.metadata.persistence?.fingerprint {
                        SupportHashBlock(title: "Project fingerprint", hash: fingerprint)
                            .padding(.top, 12)
                            .supportRuledDivider()
                    }
                    SupportDiagnosticRow("Roster", value: CommenterFormatters.integer(project.roster.count), systemImage: "person.2")
                    SupportDiagnosticRow("Selected subjects", value: CommenterFormatters.integer(project.metadata.selectedSubjects.count), systemImage: "book")
                    SupportDiagnosticRow("Results", value: CommenterFormatters.integer(project.results.count), systemImage: "chart.bar")
                    SupportDiagnosticRow("Draft reports", value: CommenterFormatters.integer(project.reports.count), systemImage: "doc.text")
                    if let readiness = state.selectedProjectReadiness {
                        SupportDiagnosticRow(
                            "Export readiness",
                            value: "\(readiness.ready) of \(readiness.expected)",
                            systemImage: "checkmark.circle",
                            valueTone: readiness.blocked.isEmpty ? .success : .warning
                        )
                        if !readiness.blocked.isEmpty {
                            DisclosureGroup("Blocked readiness details") {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(readiness.blocked.map(\.message), id: \.self) { message in
                                        SupportBodyText(message)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                            .padding(.vertical, 12)
                        }
                    }
                } else {
                    SupportDiagnosticRow("Project", value: "None open")
                    SupportBodyText("Open a project to include project-specific storage, fingerprint, roster, result, and export-readiness diagnostics.")
                        .padding(.vertical, 12)
                }
            }
        }
    }

    private var preparedFilesSection: some View {
        supportSection("Prepared files", tone: state.lastPreparedFiles.isEmpty ? .neutral : .prepared) {
            VStack(alignment: .leading, spacing: 0) {
                if state.lastPreparedFiles.isEmpty {
                    SupportDiagnosticRow("Prepared files", value: "None yet")
                } else {
                    ForEach(ImportExportFormat.preparationDisplayOrder, id: \.self) { format in
                        if let record = state.lastPreparedFiles[format] {
                            VStack(alignment: .leading, spacing: 6) {
                                SupportDiagnosticRow(
                                    format.supportLabel,
                                    value: record.filename,
                                    valueTone: .prepared,
                                    accessibilityIdentifier: format == .docx ? "support-ready-file" : "support-ready-file-\(format.rawValue)"
                                )
                                SupportBodyText("Prepared: \(CommenterFormatters.timestamp(record.preparedAtMilliseconds))")
                                    .padding(.bottom, 10)
                            }
                            .supportRuledDivider()
                        }
                    }
                }
            }
        }
    }

    private var privacyGuidanceSection: some View {
        supportSection("Privacy guidance", tone: .local) {
            VStack(alignment: .leading, spacing: 12) {
                SupportBodyText("Project names, roster data, results, draft comments, backups, and report files stay on this device unless you choose a native file export or share destination.")
                SupportBodyText("Report Writer does not configure accounts, cloud sync, analytics, telemetry, remote AI, or backend project persistence in this MVP.")
                SupportBodyText("Clipboard diagnostics are redacted by default. Prepared export files are removed after save, share, cancellation, or dismissal.")
                if let privacyPolicyURL = AppPrivacyPolicy.url() {
                    Link(destination: privacyPolicyURL) {
                        Label("Open Privacy Policy", systemImage: "hand.raised")
                            .font(.footnote.weight(.semibold))
                    }
                    .accessibilityIdentifier("privacy-policy-link")
                }
            }
        }
    }

    private var backupFeedbackSection: some View {
        supportSection("Backup and feedback", tone: .action) {
            VStack(alignment: .leading, spacing: 14) {
                SupportBodyText("Prepare Backup JSON before device migration, destructive edits, deletion, or support troubleshooting. Deleting or replacing a verified local project attempts a local recovery snapshot first.")

                Button(action: onCopyDiagnostics) {
                    StationeryActionRow(
                        title: "Report a bug: copy redacted diagnostics",
                        subtitle: "Paste the redacted diagnostic block into your support email or issue tracker.",
                        systemImage: "envelope",
                        tone: .action,
                        isEnabled: canCopyDiagnostics,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canCopyDiagnostics)
            }
        }
    }

    @ViewBuilder
    private var datasetStatusContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch state.datasetStatus {
            case .notLoaded, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking bundled comment engine")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .accessibilityElement(children: .combine)
            case let .loaded(snapshot):
                SupportDiagnosticRow(
                    "Status",
                    value: "Bundled dataset loaded",
                    valueTone: .local,
                    accessibilityIdentifier: "dataset-loaded-status"
                )
                if snapshot.hash == snapshot.normalizedSourceHash {
                    StationeryStatusChip("Verified match", systemImage: "checkmark.seal", tone: .success)
                        .padding(.vertical, 12)
                    SupportBodyText("The bundled hash matches the normalized source hash, so the packaged dataset and normalized source data identify the same production data.")
                        .padding(.bottom, 12)
                        .supportRuledDivider()
                } else {
                    StationeryStatusChip("Hash mismatch", systemImage: "exclamationmark.triangle", tone: .failure)
                        .padding(.vertical, 12)
                    SupportBodyText("The bundled hash and normalized source hash do not match. Capture diagnostics before generating or exporting reports.")
                        .padding(.bottom, 12)
                        .supportRuledDivider()
                }
                DisclosureGroup("Structural checks passed") {
                    SupportBodyText("Schema version, subject count integrity, component count, recipe count, assembled variant count, and uniqueness guard count loaded without structural errors.")
                        .padding(.top, 8)
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                .padding(.vertical, 12)
                .supportRuledDivider()
                SupportDiagnosticRow("Last validated", value: CommenterFormatters.timestamp(snapshot.loadedAtMilliseconds))
                SupportDiagnosticRow("Subjects", value: CommenterFormatters.integer(snapshot.subjectCount))
                SupportDiagnosticRow("Components", value: CommenterFormatters.integer(snapshot.componentCount))
                SupportDiagnosticRow("Recipes", value: CommenterFormatters.integer(snapshot.recipeCount))
                SupportDiagnosticRow("Assembled variants", value: CommenterFormatters.integer(snapshot.assembledVariantCount))
                SupportDiagnosticRow("Uniqueness rules", value: CommenterFormatters.integer(snapshot.uniquenessGuardCount))
                if !snapshot.warnings.isEmpty {
                    DisclosureGroup("Dataset warnings") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(snapshot.warnings, id: \.self) { warning in
                                SupportBodyText(warning)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    .padding(.vertical, 12)
                    .supportRuledDivider()
                }
                SupportHashBlock(title: "Bundled hash", hash: snapshot.hash)
                    .padding(.vertical, 12)
                    .supportRuledDivider()
                SupportHashBlock(title: "Normalized source hash", hash: snapshot.normalizedSourceHash)
                    .padding(.top, 12)
            case let .failed(message):
                UnavailableFeatureNotice(title: "Dataset blocked", message: message)
            }
        }
    }

    private func supportSection<Content: View>(
        _ title: String,
        detail: String? = nil,
        tone: StationeryTone = .neutral,
        clipped: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TapeLabel(title, tone: tone)
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.callout.italic())
                    .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 8)
            }
            NotebookCard(showsPaperclip: clipped) {
                content()
            }
        }
    }

    private var canCopyDiagnostics: Bool {
        if case .busy = state.operationStatus { return false }
        return true
    }

    private var datasetSectionTone: StationeryTone {
        switch state.datasetStatus {
        case .loaded:
            return .local
        case .failed:
            return .failure
        case .notLoaded, .loading:
            return .neutral
        }
    }

    private var storageStatusTone: StationeryTone {
        switch state.projectStorageStatus {
        case .loaded:
            return .local
        case .failed:
            return .failure
        case .notLoaded, .loading, .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
            return .neutral
        }
    }

    private var operationStatusTone: StationeryTone {
        switch state.operationStatus {
        case .idle:
            return .neutral
        case .dirty:
            return .warning
        case .busy:
            return .neutral
        case .saved:
            return .success
        case .prepared:
            return .prepared
        case .shared:
            return .success
        case .cancelled:
            return .warning
        case .failed:
            return .failure
        }
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

private struct SupportDiagnosticRow: View {
    let label: String
    let value: String
    let systemImage: String?
    let valueTone: StationeryTone?
    let accessibilityIdentifier: String?

    init(
        _ label: String,
        value: String,
        systemImage: String? = nil,
        valueTone: StationeryTone? = nil,
        accessibilityIdentifier: String? = nil
    ) {
        self.label = label
        self.value = value
        self.systemImage = systemImage
        self.valueTone = valueTone
        self.accessibilityIdentifier = accessibilityIdentifier
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                    .frame(width: 24)
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
            Spacer(minLength: 12)
            Text(value)
                .font(.body)
                .foregroundStyle(valueTone?.color ?? CommenterStationeryTheme.Colors.secondaryInk)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44)
        .padding(.vertical, 7)
        .supportRuledDivider()
        .accessibilityElement(children: .combine)
        .modifier(SupportAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }
}

private struct SupportBodyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SupportHashBlock: View {
    let title: String
    let hash: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
            Text(groupedHash)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CommenterStationeryTheme.Colors.localGreenSoft, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(hash)")
    }

    private var groupedHash: String {
        guard !hash.isEmpty else { return "Not available" }
        return stride(from: 0, to: hash.count, by: 8).map { index in
            let start = hash.index(hash.startIndex, offsetBy: index)
            let end = hash.index(start, offsetBy: min(8, hash.distance(from: start, to: hash.endIndex)))
            return String(hash[start..<end])
        }.joined(separator: " ")
    }
}

private struct SupportAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private extension View {
    func supportRuledDivider() -> some View {
        overlay(alignment: .bottom) {
            Rectangle()
                .fill(CommenterStationeryTheme.Colors.paperLine)
                .frame(height: 1)
        }
    }
}
