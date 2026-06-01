import CommentEngine
import CommenterDomain
import CommenterImportExport
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
        Section("Project") {
            TextField("Project name", text: Binding(get: { project.metadata.name }, set: onNameChanged))
                .disabled(isDisabled)
                .accessibilityIdentifier("project-name-field")
            TextField("Term", text: Binding(get: { project.metadata.term }, set: onTermChanged))
                .disabled(isDisabled)
                .accessibilityIdentifier("project-term-field")
            Picker("Project year level", selection: Binding(get: { project.metadata.yearLevel }, set: onYearLevelChanged)) {
                Text("Year 5").tag(ProjectYearLevel.year5)
                Text("Year 6").tag(ProjectYearLevel.year6)
                Text("Mixed").tag(ProjectYearLevel.mixed)
            }
            .disabled(isDisabled)
            Toggle("Use first names in reports", isOn: Binding(get: { project.metadata.useFirstNameOnly }, set: onUseFirstNameOnlyChanged))
                .disabled(isDisabled)
            Button(action: onSave) {
                Label("Save Project", systemImage: "externaldrive")
            }
            .disabled(isDisabled)
            .accessibilityIdentifier("save-project-button")
            Button(role: .destructive, action: onDeleteProject) {
                Label("Delete Project", systemImage: "trash")
            }
            .disabled(isDisabled || deleteDisabledReason != nil)
            if let deleteDisabledReason {
                Text(deleteDisabledReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Deleting a project first creates a local recovery snapshot, then removes the verified project file and returns to Projects.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ImportPreviewSection: View {
    let preview: AppFeature.PendingImport
    let isSaving: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Section("Import Preview") {
            Text(preview.title)
                .font(.headline)
            Text(preview.detail)
                .foregroundStyle(.secondary)
            if isSaving {
                ProgressView("Saving confirmed import and verifying local storage")
            } else {
                Text("Project data will not change until this import is confirmed and the local save verifies.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onConfirm) {
                Label("Confirm Import", systemImage: "checkmark.circle")
            }
            .disabled(isSaving)
            Button(role: .cancel, action: onCancel) {
                Label("Cancel Import", systemImage: "xmark.circle")
            }
            .disabled(isSaving)
        }
    }
}

struct RosterSection: View {
    let project: Project
    let onAddStudent: () -> Void
    let onDeleteStudent: (String) -> Void
    let onFirstNameChanged: (String, String) -> Void
    let onLastNameChanged: (String, String) -> Void
    let onYearChanged: (String, StudentYearLevel) -> Void
    let onImportRoster: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section("Roster") {
            Button(action: onImportRoster) {
                Label("Import Roster CSV, XLSX, or XLS", systemImage: "tray.and.arrow.down")
            }
            .disabled(isDisabled)
            Button(action: onAddStudent) {
                Label("Add Student", systemImage: "person.badge.plus")
            }
            .disabled(isDisabled)
            .accessibilityIdentifier("add-student-button")
            ForEach(project.roster) { student in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("First name", text: Binding(get: { student.firstName }, set: { onFirstNameChanged(student.id, $0) }))
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-first-name-\(student.id)")
                        TextField("Last name", text: Binding(get: { student.lastName }, set: { onLastNameChanged(student.id, $0) }))
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-last-name-\(student.id)")
                    }
                    Picker("Year", selection: Binding(get: { student.yearLevel }, set: { onYearChanged(student.id, $0) })) {
                        Text("Year 5").tag(StudentYearLevel.year5)
                        Text("Year 6").tag(StudentYearLevel.year6)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDisabled)
                    Button(role: .destructive) {
                        onDeleteStudent(student.id)
                    } label: {
                        Label("Delete Student", systemImage: "trash")
                    }
                    .disabled(isDisabled)
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("student-card-\(student.id)")
            }
        }
    }
}

struct SubjectsSection: View {
    let project: Project
    let onSubjectToggled: (String) -> Void
    let isDisabled: Bool

    var body: some View {
        Section("Subjects") {
            ForEach(availableTeacherSubjects(), id: \.self) { subject in
                Toggle(
                    subject,
                    isOn: Binding(
                        get: { project.metadata.selectedSubjects[subject] != nil },
                        set: { _ in onSubjectToggled(subject) }
                    )
                )
                .disabled(isDisabled)
                .accessibilityIdentifier("subject-toggle-\(accessibilityKey(subject))")
                if subjectRequiresConcreteFocus(subject), project.metadata.selectedSubjects[subject] != nil {
                    Text("Specific focus is required for \(subject) results: \(getConcreteFocusOptions(subject).joined(separator: ", ")).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct ResultsSection: View {
    let project: Project
    let readiness: ProjectReadiness?
    let onAchievementChanged: (String, String, AchievementLevel?) -> Void
    let onFocusChanged: (String, String, String) -> Void
    let onImportResults: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section("Results") {
            Button(action: onImportResults) {
                Label("Import Results CSV, XLSX, or XLS", systemImage: "tray.and.arrow.down")
            }
            .disabled(isDisabled || project.roster.isEmpty || selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty)
            if project.roster.isEmpty || selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty {
                Text("Add at least one student and select at least one subject before importing results.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(project.roster) { student in
                ForEach(selectedSubjectKeys(project.metadata.selectedSubjects), id: \.self) { subject in
                    let result = project.results.first { $0.studentId == student.id && $0.subject == subject }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(student.firstName) \(student.lastName) - \(subject)")
                            .font(.headline)
                        Picker(
                            "Achievement",
                            selection: Binding(
                                get: { result?.achievementLevel },
                                set: { onAchievementChanged(student.id, subject, $0) }
                            )
                        ) {
                            Text("Missing").tag(Optional<AchievementLevel>.none)
                            Text("Beginning").tag(Optional(AchievementLevel.beginning))
                            Text("Developing").tag(Optional(AchievementLevel.developing))
                            Text("At Standard").tag(Optional(AchievementLevel.atStandard))
                            Text("Above Standard").tag(Optional(AchievementLevel.aboveStandard))
                        }
                        .disabled(isDisabled)
                        .accessibilityIdentifier("achievement-picker-\(student.id)-\(accessibilityKey(subject))")
                        if subjectRequiresConcreteFocus(subject) {
                            Picker("Specific subject", selection: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) })) {
                                Text("Choose").tag("")
                                ForEach(getConcreteFocusOptions(subject), id: \.self) { focus in
                                    Text(focus).tag(focus)
                                }
                            }
                            .disabled(isDisabled)
                        } else {
                            TextField("Focus", text: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) }))
                                .disabled(isDisabled)
                                .accessibilityIdentifier("focus-field-\(student.id)-\(accessibilityKey(subject))")
                        }
                        if let entry = readiness?.entries.first(where: { $0.studentId == student.id && $0.subject == subject }) {
                            Label(entry.message, systemImage: isReadyForExport(entry.status) ? "checkmark.circle" : "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(isReadyForExport(entry.status) ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("result-card-\(student.id)-\(accessibilityKey(subject))")
                }
            }
        }
    }
}

struct ReportsSection: View {
    let project: Project
    let onGenerate: () -> Void
    let onManualEditChanged: (String, String, String) -> Void
    let onLockChanged: (String, String, Bool) -> Void
    let isDisabled: Bool

    var body: some View {
        Section("Draft Comments") {
            Button(action: onGenerate) {
                Label("Generate and Save Reports", systemImage: "sparkles")
            }
            .disabled(isDisabled || project.roster.isEmpty || selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty)
            .accessibilityIdentifier("generate-reports-button")
            if project.roster.isEmpty || selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty {
                Text("Add students and selected subjects before generating draft comments.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(project.reports, id: \.reportListIdentifier) { report in
                VStack(alignment: .leading, spacing: 8) {
                    Text(reportTitle(report, project: project))
                        .font(.headline)
                    TextEditor(text: Binding(
                        get: { report.manualEdit ?? report.text },
                        set: { onManualEditChanged(report.studentId, report.subject, $0) }
                    ))
                    .frame(minHeight: 120)
                    .disabled(isDisabled)
                    .accessibilityIdentifier("report-editor-\(report.studentId)-\(accessibilityKey(report.subject))")
                    Toggle("Lock against regeneration", isOn: Binding(get: { report.isLocked }, set: { onLockChanged(report.studentId, report.subject, $0) }))
                        .disabled(isDisabled)
                }
            }
        }
    }
}

struct ExportSection: View {
    let preparedFile: AppFeature.PreparedFile?
    let hasHiddenStalePreparedFile: Bool
    let readiness: ProjectReadiness?
    let onPrepareBackup: () -> Void
    let onPrepareExport: (ImportExportFormat) -> Void
    let onSavePreparedFile: () -> Void
    let onSharePreparedFile: () -> Void
    let onDismissPreparedFile: () -> Void
    let isDisabled: Bool
    let disabledReason: String?

    var body: some View {
        Section("Export and Backup") {
            Button(action: onPrepareBackup) {
                Label("Prepare Backup JSON", systemImage: "externaldrive")
            }
            .disabled(isDisabled)
            Button { onPrepareExport(.docx) } label: {
                Label("Prepare DOCX Reports", systemImage: "doc.richtext")
            }
            .disabled(isDisabled || !canPrepareReports)
            .accessibilityIdentifier("prepare-docx-reports-button")
            Button { onPrepareExport(.xlsx) } label: {
                Label("Prepare XLSX Review Workbook", systemImage: "tablecells")
            }
            .disabled(isDisabled || !canPrepareReports)
            Button { onPrepareExport(.xls) } label: {
                Label("Prepare Legacy XLS Review Workbook", systemImage: "tablecells.badge.ellipsis")
            }
            .disabled(isDisabled || !canPrepareReports)
            if isDisabled {
                Text(disabledReason ?? "Backup and export preparation is paused until the current project state is available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !canPrepareReports {
                Text(exportBlockedMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hasHiddenStalePreparedFile {
                Text("A previously prepared file is hidden because the project has unsaved changes. Save and prepare a new file before exporting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let preparedFile {
                Label("Verified prepared file is ready", systemImage: "checkmark.seal")
                    .foregroundStyle(.blue)
                    .accessibilityIdentifier("prepared-file-ready")
                LabeledContent("Prepared file", value: preparedFile.url.lastPathComponent)
                Text(preparedFile.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: onSavePreparedFile) {
                    Label("Save Prepared File Copy", systemImage: "square.and.arrow.down")
                }
                .disabled(isDisabled)
                Button(action: onSharePreparedFile) {
                    Label("Share Prepared File", systemImage: "square.and.arrow.up")
                }
                .disabled(isDisabled)
                Text("This file has been prepared and verified locally. Saving reports success only after the file exporter returns; sharing records completed, cancelled, or failed native share outcomes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: onDismissPreparedFile) {
                    Label("Dismiss Prepared File", systemImage: "xmark")
                }
                .disabled(isDisabled)
            }
        }
    }

    private var canPrepareReports: Bool {
        guard let readiness else {
            return false
        }
        return readiness.expected > 0 && readiness.ready == readiness.expected
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

private func reportTitle(_ report: GeneratedReport, project: Project) -> String {
    let student = project.roster.first { $0.id == report.studentId }
    let name = [student?.firstName, student?.lastName].compactMap { $0 }.joined(separator: " ")
    return "\(name.isEmpty ? "Student" : name) - \(report.subject)"
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
