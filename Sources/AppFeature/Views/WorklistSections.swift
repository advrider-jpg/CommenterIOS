import CommentEngine
import CommenterDomain
import CommenterImportExport
import DesignSystem
import SwiftUI

struct ProjectMetadataSection: View {
    let project: Project
    let onNameChanged: (String) -> Void
    let onTermChanged: (String) -> Void
    let onYearLevelChanged: (ProjectYearLevel) -> Void
    let onUseFirstNameOnlyChanged: (Bool) -> Void
    let onSave: () -> Void
    let onDeleteProject: () -> Void
    let isDisabled: Bool
    let deleteDisabledReason: String?

    var body: some View {
        Section {
            TextField("Project name", text: Binding(get: { project.metadata.name }, set: onNameChanged))
                .commenterWordsTextInput()
                .disabled(isDisabled)
                .accessibilityHint("Use a descriptive class and year name.")
                .accessibilityIdentifier("project-name-field")
            HStack(spacing: 10) {
                Image(systemName: "pencil.line")
                    .foregroundStyle(CommenterColors.accent)
                    .accessibilityHidden(true)
                TextField("Term", text: Binding(get: { project.metadata.term }, set: onTermChanged))
                    .disabled(isDisabled)
                    .accessibilityIdentifier("project-term-field")
            }
            Picker("Project year level", selection: Binding(get: { project.metadata.yearLevel }, set: onYearLevelChanged)) {
                Text("Year 5").tag(ProjectYearLevel.year5)
                Text("Year 6").tag(ProjectYearLevel.year6)
                Text("Mixed").tag(ProjectYearLevel.mixed)
            }
            .disabled(isDisabled)
            Toggle(isOn: Binding(get: { project.metadata.useFirstNameOnly }, set: onUseFirstNameOnlyChanged)) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Use first names in reports")
                    Text("Applies to generated draft text and prepared DOCX/XLSX/XLS report headings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .disabled(isDisabled)
            Button(action: onSave) {
                CommenterActionRow(
                    title: "Save Project",
                    subtitle: lastSavedText,
                    systemImage: "square.and.arrow.down",
                    isEnabled: !isDisabled,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityIdentifier("save-project-button")
        } header: {
            CommenterSectionHeader("Project", step: 1, detail: "Name, class context, save status")
        }

        Section {
            Button(role: .destructive, action: onDeleteProject) {
                CommenterActionRow(
                    title: "Delete Project",
                    subtitle: deleteSubtitle,
                    systemImage: "trash",
                    isEnabled: !isDisabled && deleteDisabledReason == nil,
                    isDestructive: true,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled || deleteDisabledReason != nil)
        } header: {
            CommenterSectionHeader("Danger zone")
        } footer: {
            Text("A confirmation dialog appears before deletion. A local recovery snapshot is created first when the verified project file can be reached.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lastSavedText: String {
        "Last saved: \(CommenterFormatters.timestamp(project.metadata.persistence?.savedAt))"
    }

    private var deleteSubtitle: String {
        deleteDisabledReason ?? "Creates a recovery snapshot, removes the verified project file, and returns to Projects."
    }
}

struct ImportPreviewSection: View {
    let preview: AppFeature.PendingImport
    let isSaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(preview.title)
                    .font(.headline)
                Text(preview.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                StatusChip("\(preview.acceptedRows) accepted", systemImage: "checkmark.seal", tone: preview.acceptedRows > 0 ? .success : .warning)
            }
            if isSaving {
                ProgressView("Saving confirmed import and verifying local storage")
            } else {
                Text("Project data will not change until this import is confirmed and the local save verifies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onConfirm) {
                CommenterActionRow(title: "Confirm Import", systemImage: "checkmark.circle", isEnabled: !isSaving, showsChevron: false)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
            Button(role: .cancel, action: onCancel) {
                CommenterActionRow(title: "Cancel Import", systemImage: "xmark.circle", isEnabled: !isSaving, showsChevron: false)
            }
            .buttonStyle(.plain)
            .disabled(isSaving)
        } header: {
            CommenterSectionHeader("Import preview", detail: "All-or-nothing local save")
        }
    }
}

struct RosterSection: View {
    let project: Project
    let importState: AppFeature.TabularImportState
    let onAddStudent: () -> Void
    let onDeleteStudent: (String) -> Void
    let onFirstNameChanged: (String, String) -> Void
    let onLastNameChanged: (String, String) -> Void
    let onYearChanged: (String, StudentYearLevel) -> Void
    let onImportRoster: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            tabularImportStatus(importState, emptyLabel: "Roster not imported")
            Button(action: onImportRoster) {
                CommenterActionRow(
                    title: "Import Roster CSV, XLSX, or XLS",
                    subtitle: "Preview and confirm student names before the verified local project changes.",
                    systemImage: "square.and.arrow.down",
                    isEnabled: !isDisabled
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            Button(action: onAddStudent) {
                CommenterActionRow(
                    title: "Add Student",
                    subtitle: "Add a student manually when a roster file is not available.",
                    systemImage: "person.badge.plus",
                    isEnabled: !isDisabled
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            .accessibilityIdentifier("add-student-button")

            if project.roster.isEmpty {
                CommenterEmptyState(
                    systemImage: "person.2.badge.plus",
                    title: "No students yet",
                    message: "Add students manually or import a roster file before entering results or generating draft comments."
                )
            } else {
                ForEach(project.roster) { student in
                    NavigationLink {
                        StudentEditorView(
                            student: student,
                            isDisabled: isDisabled,
                            onFirstNameChanged: { onFirstNameChanged(student.id, $0) },
                            onLastNameChanged: { onLastNameChanged(student.id, $0) },
                            onYearChanged: { onYearChanged(student.id, $0) },
                            onDelete: { onDeleteStudent(student.id) }
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fullStudentName(student))
                                .font(.body.weight(.semibold))
                            Text(student.yearLevel.rawValue)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isDisabled)
                    .accessibilityIdentifier("student-row-\(student.id)")
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onDeleteStudent(student.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(isDisabled)
                    }
                }
            }
        } header: {
            CommenterSectionHeader("Roster", step: 2, detail: "Students required before results and drafts")
        }
    }
}

private struct StudentEditorView: View {
    let student: Student
    let isDisabled: Bool
    let onFirstNameChanged: (String) -> Void
    let onLastNameChanged: (String) -> Void
    let onYearChanged: (StudentYearLevel) -> Void
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section {
                TextField("First name", text: Binding(get: { student.firstName }, set: onFirstNameChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("student-first-name-\(student.id)")
                TextField("Last name", text: Binding(get: { student.lastName }, set: onLastNameChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("student-last-name-\(student.id)")
                Picker("Year", selection: Binding(get: { student.yearLevel }, set: onYearChanged)) {
                    Text("Year 5").tag(StudentYearLevel.year5)
                    Text("Year 6").tag(StudentYearLevel.year6)
                }
                .pickerStyle(.segmented)
                .disabled(isDisabled)
            } header: {
                CommenterSectionHeader("Student details")
            }
            Section {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Student", systemImage: "trash")
                }
                .disabled(isDisabled)
            }
        }
        .navigationTitle(fullStudentName(student))
        .commenterInlineNavigationTitle()
    }
}

struct SubjectsSection: View {
    let project: Project
    let onSubjectToggled: (String) -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            HStack {
                Button("Select all", action: onSelectAll)
                    .disabled(isDisabled || selectedSubjectCount == availableTeacherSubjects().count)
                Spacer()
                Button("Deselect all", role: .destructive, action: onDeselectAll)
                    .disabled(isDisabled || selectedSubjectCount == 0)
                    .accessibilityIdentifier("subject-deselect-all-button")
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
            Text("Select the curriculum areas to include in this reporting cycle. At least one subject is required before results can be imported or drafts generated.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(australianCurriculumSubjectOrder) { descriptor in
                Toggle(isOn: Binding(
                    get: { project.metadata.selectedSubjects[descriptor.key] != nil },
                    set: { _ in onSubjectToggled(descriptor.key) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(descriptor.displayName)
                        Text(descriptor.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .disabled(isDisabled)
                .accessibilityIdentifier("subject-toggle-\(accessibilityKey(descriptor.key))")
                if subjectRequiresConcreteFocus(descriptor.key), project.metadata.selectedSubjects[descriptor.key] != nil {
                    Text("Specific focus required: \(getConcreteFocusOptions(descriptor.key).joined(separator: ", ")).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            CommenterSectionHeader("Subjects", step: 3, detail: "Australian Curriculum order")
        }
    }

    private var selectedSubjectCount: Int {
        selectedSubjectKeys(project.metadata.selectedSubjects).count
    }
}

struct ResultsSection: View {
    let project: Project
    let readiness: ProjectReadiness?
    let importState: AppFeature.TabularImportState
    let onAchievementChanged: (String, String, AchievementLevel?) -> Void
    let onFocusChanged: (String, String, String) -> Void
    let onImportResults: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            tabularImportStatus(importState, emptyLabel: "Results not imported")
            Button(action: onImportResults) {
                CommenterActionRow(
                    title: "Import Results CSV, XLSX, or XLS",
                    subtitle: resultsImportSubtitle,
                    systemImage: "square.and.arrow.down",
                    isEnabled: canImportResults
                )
            }
            .buttonStyle(.plain)
            .disabled(!canImportResults)
            if let disabledMessage = resultsImportDisabledMessage {
                Text(disabledMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if project.roster.isEmpty || selectedSubjects.isEmpty {
                CommenterEmptyState(
                    systemImage: "chart.bar.doc.horizontal",
                    title: "Results waiting for prerequisites",
                    message: resultsImportDisabledMessage ?? "Add students and select subjects before entering results."
                )
            } else if project.results.isEmpty {
                CommenterEmptyState(
                    systemImage: "tray.and.arrow.down",
                    title: "No results recorded",
                    message: "Import a results file or enter achievement levels manually for each selected student and subject."
                )
            }

            ForEach(project.roster) { student in
                ForEach(selectedSubjects, id: \.self) { subject in
                    let result = project.results.first { $0.studentId == student.id && $0.subject == subject }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(fullStudentName(student)) - \(displaySubjectName(subject))")
                            .font(.headline)
                        AchievementLevelMenu(
                            selection: result?.achievementLevel,
                            onSelectionChanged: { onAchievementChanged(student.id, subject, $0) },
                            isDisabled: isDisabled,
                            accessibilityIdentifier: "achievement-picker-\(student.id)-\(accessibilityKey(subject))"
                        )
                        if subjectRequiresConcreteFocus(subject) {
                            Picker("Specific subject", selection: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) })) {
                                Text("Choose").tag("")
                                ForEach(getConcreteFocusOptions(subject), id: \.self) { focus in
                                    Text(focus).tag(focus)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(isDisabled)
                            .accessibilityIdentifier("focus-picker-\(student.id)-\(accessibilityKey(subject))")
                        } else {
                            TextField("Focus", text: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) }))
                                .disabled(isDisabled)
                                .accessibilityIdentifier("focus-field-\(student.id)-\(accessibilityKey(subject))")
                        }
                        if let entry = readiness?.entries.first(where: { $0.studentId == student.id && $0.subject == subject }) {
                            Label(entry.message, systemImage: isReadyForExport(entry.status) ? "checkmark.circle" : "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(isReadyForExport(entry.status) ? CommenterColors.success : CommenterColors.warning)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("result-card-\(student.id)-\(accessibilityKey(subject))")
                }
            }
        } header: {
            CommenterSectionHeader("Results", step: 4, detail: "Distinct empty, failed, zero-row, and success states")
        }
    }

    private var selectedSubjects: [String] {
        selectedSubjectKeys(project.metadata.selectedSubjects)
    }

    private var canImportResults: Bool {
        !isDisabled && project.roster.isEmpty == false && selectedSubjects.isEmpty == false
    }

    private var resultsImportSubtitle: String {
        canImportResults ? "Preview result rows before the verified local project changes." : "Complete the listed prerequisites first."
    }

    private var resultsImportDisabledMessage: String? {
        var messages: [String] = []
        if isDisabled { messages.append("Wait for the current operation or import preview to finish.") }
        if project.roster.isEmpty { messages.append("Add at least one student.") }
        if selectedSubjects.isEmpty { messages.append("Select at least one subject.") }
        return messages.isEmpty ? nil : messages.joined(separator: " ")
    }
}

private struct AchievementLevelMenu: View {
    let selection: AchievementLevel?
    let onSelectionChanged: (AchievementLevel?) -> Void
    let isDisabled: Bool
    let accessibilityIdentifier: String

    var body: some View {
        Menu {
            Button("Missing") {
                onSelectionChanged(nil)
            }
            Divider()
            ForEach(achievementLevelOptions, id: \.rawValue) { level in
                Button(level.rawValue) {
                    onSelectionChanged(level)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("Achievement")
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(selection?.rawValue ?? "Missing")
                    .foregroundStyle(selection == nil ? .secondary : CommenterColors.accent)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Achievement")
        .accessibilityValue(selection?.rawValue ?? "Missing")
    }
}

private let achievementLevelOptions: [AchievementLevel] = [
    .beginning,
    .developing,
    .atStandard,
    .aboveStandard
]

struct ReportsSection: View {
    let project: Project
    let readiness: ProjectReadiness?
    let datasetStatus: AppFeature.DatasetStatus
    let isGenerating: Bool
    let onGenerate: () -> Void
    let onManualEditChanged: (String, String, String) -> Void
    let onLockChanged: (String, String, Bool) -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            Button(action: onGenerate) {
                CommenterActionRow(
                    title: reportGenerationButtonTitle(project: project, readiness: readiness),
                    subtitle: generationSubtitle,
                    systemImage: "text.bubble",
                    isEnabled: canGenerate,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(!canGenerate)
            .accessibilityIdentifier("generate-reports-button")
            if isGenerating {
                ProgressView("Generating deterministic draft comments")
            }
            if let disabledReason = generationDisabledReason {
                Text(disabledReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if readiness?.entries.contains(where: { $0.status == .staleReport || $0.status == .lockedStale }) == true {
                StatusChip("Stale drafts need review", systemImage: "arrow.triangle.2.circlepath", tone: .warning)
            }
            if project.reports.isEmpty {
                CommenterEmptyState(
                    systemImage: "text.bubble",
                    title: "No draft comments yet",
                    message: "Draft comments are generated deterministically from the bundled local dataset after roster, subjects, and results are ready."
                )
            }
            ForEach(project.reports, id: \.reportListIdentifier) { report in
                NavigationLink {
                    ReportEditorView(
                        report: report,
                        project: project,
                        isDisabled: isDisabled,
                        onManualEditChanged: { onManualEditChanged(report.studentId, report.subject, $0) },
                        onLockChanged: { onLockChanged(report.studentId, report.subject, $0) }
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reportTitle(report, project: project))
                            .font(.body.weight(.semibold))
                        Text(report.isLocked ? "Locked against regeneration" : "Editable draft")
                            .font(.footnote)
                            .foregroundStyle(report.isLocked ? CommenterColors.warning : .secondary)
                    }
                }
                .accessibilityIdentifier("report-row-\(report.studentId)-\(accessibilityKey(report.subject))")
            }
        } header: {
            CommenterSectionHeader("Draft reports", step: 5, detail: "Deterministic local draft generation")
        }
    }

    private var generationDisabledReason: String? {
        if isDisabled { return "Wait for the current operation or import preview to finish before generating draft comments." }
        return reportGenerationDisabledReason(project: project, readiness: readiness, datasetStatus: datasetStatus)
    }

    private var canGenerate: Bool {
        generationDisabledReason == nil
    }

    private var generationSubtitle: String {
        generationDisabledReason ?? "Creates local draft comments and saves only after project verification succeeds."
    }
}

private struct ReportEditorView: View {
    let report: GeneratedReport
    let project: Project
    let isDisabled: Bool
    let onManualEditChanged: (String) -> Void
    let onLockChanged: (Bool) -> Void

    var body: some View {
        Form {
            Section {
                TextEditor(text: Binding(
                    get: { report.manualEdit ?? report.text },
                    set: onManualEditChanged
                ))
                .frame(minHeight: 220)
                .disabled(isDisabled)
                .accessibilityIdentifier("report-editor-\(report.studentId)-\(accessibilityKey(report.subject))")
                Toggle("Lock against regeneration", isOn: Binding(get: { report.isLocked }, set: onLockChanged))
                    .disabled(isDisabled)
            } header: {
                CommenterSectionHeader("Draft text")
            } footer: {
                Text("Locked drafts are preserved during regeneration. Unlocked stale drafts can be regenerated from current results and selected subjects.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle(reportTitle(report, project: project))
        .commenterInlineNavigationTitle()
    }
}

struct ReportExportsSection: View {
    let readiness: ProjectReadiness?
    let records: [ImportExportFormat: AppFeature.PreparedFileRecord]
    let onPrepareExport: (ImportExportFormat) -> Void
    let isDisabled: Bool
    let disabledReason: String?

    var body: some View {
        Section {
            ForEach([ImportExportFormat.docx, .xlsx, .xls], id: \.self) { format in
                Button { onPrepareExport(format) } label: {
                    CommenterActionRow(
                        title: format.prepareTitle,
                        subtitle: exportSubtitle(for: format),
                        systemImage: format.exportSystemImage,
                        isEnabled: !isDisabled && canPrepareReports
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled || !canPrepareReports)
                .accessibilityIdentifier(format == .docx ? "prepare-docx-reports-button" : "prepare-\(format.rawValue)-reports-button")
            }
            if isDisabled {
                Text(disabledReason ?? "Report export preparation is paused until the current project state is available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !canPrepareReports {
                Text(exportBlockedMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            CommenterSectionHeader("Reports", step: 6, detail: "Prepare delivery files after every draft is ready")
        }
    }

    private var canPrepareReports: Bool {
        guard let readiness else { return false }
        return readiness.expected > 0 && readiness.ready == readiness.expected
    }

    private func exportSubtitle(for format: ImportExportFormat) -> String {
        let timestamp = records[format].map { "Last prepared: \(CommenterFormatters.timestamp($0.preparedAtMilliseconds))" } ?? "Not yet prepared"
        return "\(format.explainer). \(timestamp)."
    }

    private var exportBlockedMessage: String {
        guard let readiness else {
            return "Open a project before preparing report exports."
        }
        if readiness.expected == 0 {
            return "Add students, subjects, results, and draft comments before preparing report exports."
        }
        return "\(readiness.ready) of \(readiness.expected) reports are export-ready. Finish blocked drafts before preparing report exports."
    }
}

struct BackupSection: View {
    let record: AppFeature.PreparedFileRecord?
    let onPrepareBackup: () -> Void
    let isDisabled: Bool
    let disabledReason: String?

    var body: some View {
        Section {
            Button(action: onPrepareBackup) {
                CommenterActionRow(
                    title: "Prepare Backup JSON",
                    subtitle: backupSubtitle,
                    systemImage: "externaldrive.badge.checkmark",
                    isEnabled: !isDisabled,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(isDisabled)
            if isDisabled {
                Text(disabledReason ?? "Backup preparation is paused until the current project state is available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            CommenterSectionHeader("Backup", step: 7, detail: "User-owned recovery copy")
        }
    }

    private var backupSubtitle: String {
        let timestamp = record.map { "Last prepared: \(CommenterFormatters.timestamp($0.preparedAtMilliseconds))" } ?? "Not yet prepared"
        return "Prepare before device moves, destructive edits, or support troubleshooting. \(timestamp)."
    }
}

struct PreparedFileSection: View {
    let preparedFile: AppFeature.PreparedFile?
    let hasHiddenStalePreparedFile: Bool
    let onSavePreparedFile: () -> Void
    let onSharePreparedFile: () -> Void
    let onDismissPreparedFile: () -> Void
    let isDisabled: Bool

    var body: some View {
        if preparedFile != nil || hasHiddenStalePreparedFile {
            Section {
                if hasHiddenStalePreparedFile {
                    StatusChip("Prepared file hidden until current edits are saved", systemImage: "exclamationmark.triangle", tone: .warning)
                    Text("Save the project and prepare a new file so exports and shares reflect verified local state.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let preparedFile {
                    Label("Verified prepared file is ready", systemImage: "checkmark.seal")
                        .foregroundStyle(CommenterColors.success)
                        .accessibilityIdentifier("prepared-file-ready")
                    LabeledContent("Prepared file", value: preparedFile.url.lastPathComponent)
                    Text(preparedFile.label)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let preparedAt = preparedFile.preparedAtMilliseconds {
                        LabeledContent("Prepared", value: CommenterFormatters.timestamp(preparedAt))
                    }
                    Button(action: onSavePreparedFile) {
                        CommenterActionRow(title: "Save Prepared File Copy", systemImage: "square.and.arrow.down", isEnabled: !isDisabled)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    Button(action: onSharePreparedFile) {
                        CommenterActionRow(title: "Share Prepared File", systemImage: "square.and.arrow.up", isEnabled: !isDisabled)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                    Text("This file has been prepared and verified locally. Saving reports success only after the file exporter returns; sharing records completed, cancelled, or failed native share outcomes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onDismissPreparedFile) {
                        CommenterActionRow(title: "Dismiss Prepared File", systemImage: "xmark", isEnabled: !isDisabled, showsChevron: false)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled)
                }
            } header: {
                CommenterSectionHeader("Prepared file", detail: "Verified file ready for native save or share")
            }
        }
    }
}

@ViewBuilder
private func tabularImportStatus(_ state: AppFeature.TabularImportState, emptyLabel: String) -> some View {
    switch state {
    case .neverImported:
        StatusChip(emptyLabel, systemImage: "tray", tone: .neutral)
    case let .loaded(count, source):
        StatusChip("Loaded \(count) rows from \(source)", systemImage: "checkmark.seal", tone: .success)
    case let .validating(source):
        HStack {
            ProgressView()
            Text("Validating \(source)")
        }
        .accessibilityElement(children: .combine)
    case let .previewReady(count, source):
        StatusChip("Preview ready: \(count) rows from \(source)", systemImage: "doc.text.magnifyingglass", tone: .prepared)
    case let .zeroValidRecords(message):
        StatusChip(message, systemImage: "0.circle", tone: .warning)
    case let .failed(message):
        StatusChip(message, systemImage: "exclamationmark.triangle", tone: .failure)
    case let .success(count, source):
        StatusChip("Imported \(count) rows from \(source)", systemImage: "checkmark.seal", tone: .success)
    case let .stale(message):
        StatusChip(message, systemImage: "arrow.triangle.2.circlepath", tone: .warning)
    }
}

private extension ImportExportFormat {
    var prepareTitle: String {
        switch self {
        case .docx:
            return "Prepare DOCX Reports"
        case .xlsx:
            return "Prepare XLSX Review Workbook"
        case .xls:
            return "Prepare XLS Review Workbook (older Excel format)"
        case .backupJSON:
            return "Prepare Backup JSON"
        case .csv:
            return "Prepare CSV"
        }
    }

    var exportSystemImage: String {
        switch self {
        case .docx:
            return "doc.richtext"
        case .xlsx:
            return "tablecells"
        case .xls:
            return "square.grid.3x3"
        case .backupJSON:
            return "externaldrive.badge.checkmark"
        case .csv:
            return "doc.plaintext"
        }
    }

    var explainer: String {
        switch self {
        case .docx:
            return "Teacher-facing document reports"
        case .xlsx:
            return "Modern spreadsheet review workbook"
        case .xls:
            return "Older Excel workbook for systems that need XLS"
        case .backupJSON:
            return "Recovery backup"
        case .csv:
            return "CSV file"
        }
    }
}

private func reportTitle(_ report: GeneratedReport, project: Project) -> String {
    let student = project.roster.first { $0.id == report.studentId }
    let name = student.map(fullStudentName) ?? "Student"
    return "\(name) - \(displaySubjectName(report.subject))"
}

private func fullStudentName(_ student: Student) -> String {
    let name = [student.firstName, student.lastName]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    return name.isEmpty ? "Student" : name
}

private extension GeneratedReport {
    var reportListIdentifier: String {
        "\(studentId)::\(subject)"
    }
}

private func accessibilityKey(_ value: String) -> String {
    value
        .lowercased()
        .filter { $0.isLetter || $0.isNumber }
}
