import CommentEngine
import CommenterDomain
import CommenterImportExport
import SwiftUI

struct ProjectMetadataSection: View {
    let project: Project
    let onNameChanged: (String) -> Void
    let onTermChanged: (String) -> Void
    let onUseFirstNameOnlyChanged: (Bool) -> Void
    let onSave: () -> Void

    var body: some View {
        Section("Project") {
            TextField("Project name", text: Binding(get: { project.metadata.name }, set: onNameChanged))
            TextField("Term", text: Binding(get: { project.metadata.term }, set: onTermChanged))
            Toggle("Use first names in reports", isOn: Binding(get: { project.metadata.useFirstNameOnly }, set: onUseFirstNameOnlyChanged))
            Button(action: onSave) {
                Label("Save Project", systemImage: "externaldrive")
            }
        }
    }
}

struct ImportPreviewSection: View {
    let preview: AppFeature.PendingImport
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Section("Import Preview") {
            Text(preview.title)
                .font(.headline)
            Text(preview.detail)
                .foregroundStyle(.secondary)
            Button(action: onConfirm) {
                Label("Confirm Import", systemImage: "checkmark.circle")
            }
            Button(role: .cancel, action: onCancel) {
                Label("Cancel Import", systemImage: "xmark.circle")
            }
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

    var body: some View {
        Section("Roster") {
            Button(action: onImportRoster) {
                Label("Import Roster CSV, XLSX, or XLS", systemImage: "tray.and.arrow.down")
            }
            Button(action: onAddStudent) {
                Label("Add Student", systemImage: "person.badge.plus")
            }
            ForEach(project.roster) { student in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("First name", text: Binding(get: { student.firstName }, set: { onFirstNameChanged(student.id, $0) }))
                        TextField("Last name", text: Binding(get: { student.lastName }, set: { onLastNameChanged(student.id, $0) }))
                    }
                    Picker("Year", selection: Binding(get: { student.yearLevel }, set: { onYearChanged(student.id, $0) })) {
                        Text("Year 5").tag(StudentYearLevel.year5)
                        Text("Year 6").tag(StudentYearLevel.year6)
                    }
                    .pickerStyle(.segmented)
                    Button(role: .destructive) {
                        onDeleteStudent(student.id)
                    } label: {
                        Label("Delete Student", systemImage: "trash")
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct SubjectsSection: View {
    let project: Project
    let onSubjectToggled: (String) -> Void

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

    var body: some View {
        Section("Results") {
            Button(action: onImportResults) {
                Label("Import Results CSV, XLSX, or XLS", systemImage: "tray.and.arrow.down")
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
                        if subjectRequiresConcreteFocus(subject) {
                            Picker("Specific subject", selection: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) })) {
                                Text("Choose").tag("")
                                ForEach(getConcreteFocusOptions(subject), id: \.self) { focus in
                                    Text(focus).tag(focus)
                                }
                            }
                        } else {
                            TextField("Focus", text: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) }))
                        }
                        if let entry = readiness?.entries.first(where: { $0.studentId == student.id && $0.subject == subject }) {
                            Label(entry.message, systemImage: isReadyForExport(entry.status) ? "checkmark.circle" : "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(isReadyForExport(entry.status) ? .green : .orange)
                        }
                    }
                    .padding(.vertical, 4)
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

    var body: some View {
        Section("Draft Comments") {
            Button(action: onGenerate) {
                Label("Generate and Save Reports", systemImage: "sparkles")
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
                    Toggle("Lock against regeneration", isOn: Binding(get: { report.isLocked }, set: { onLockChanged(report.studentId, report.subject, $0) }))
                }
            }
        }
    }
}

struct ExportSection: View {
    let preparedFile: AppFeature.PreparedFile?
    let onPrepareBackup: () -> Void
    let onPrepareExport: (ImportExportFormat) -> Void
    let onSavePreparedFile: () -> Void
    let onDismissPreparedFile: () -> Void

    var body: some View {
        Section("Export and Backup") {
            Button(action: onPrepareBackup) {
                Label("Prepare Backup JSON", systemImage: "externaldrive")
            }
            Button { onPrepareExport(.docx) } label: {
                Label("Prepare DOCX Reports", systemImage: "doc.richtext")
            }
            Button { onPrepareExport(.xlsx) } label: {
                Label("Prepare XLSX Review Workbook", systemImage: "tablecells")
            }
            Button { onPrepareExport(.xls) } label: {
                Label("Prepare Legacy XLS Review Workbook", systemImage: "tablecells.badge.ellipsis")
            }
            if let preparedFile {
                LabeledContent("Prepared file", value: preparedFile.url.lastPathComponent)
                Text(preparedFile.label)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: onSavePreparedFile) {
                    Label("Save Prepared File", systemImage: "square.and.arrow.down")
                }
                ShareLink(item: preparedFile.url) {
                    Label("Share Prepared File", systemImage: "square.and.arrow.up")
                }
                Text("Sharing is offered only after a verified local file exists. The app records this as prepared, because the share sheet does not provide a reliable completion result here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: onDismissPreparedFile) {
                    Label("Dismiss Prepared File", systemImage: "xmark")
                }
            }
        }
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
