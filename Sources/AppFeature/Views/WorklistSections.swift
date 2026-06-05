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
            WorklistNotebookCard(clipped: true) {
                WorklistFormRow(systemImage: "book") {
                    TextField("Project name", text: Binding(get: { project.metadata.name }, set: onNameChanged))
                        .commenterWordsTextInput()
                        .disabled(isDisabled)
                        .accessibilityHint("Use a descriptive class and year name.")
                        .accessibilityIdentifier("project-name-field")
                }
                WorklistRuledDivider()
                WorklistFormRow(systemImage: "pencil") {
                    TextField("Term", text: Binding(get: { project.metadata.term }, set: onTermChanged))
                        .disabled(isDisabled)
                        .accessibilityIdentifier("project-term-field")
                }
                WorklistRuledDivider()
                WorklistFormRow {
                    Picker("Project year level", selection: Binding(get: { project.metadata.yearLevel }, set: onYearLevelChanged)) {
                        Text("Year 5").tag(ProjectYearLevel.year5)
                        Text("Year 6").tag(ProjectYearLevel.year6)
                        Text("Mixed").tag(ProjectYearLevel.mixed)
                    }
                    .disabled(isDisabled)
                }
                WorklistRuledDivider()
                Toggle(isOn: Binding(get: { project.metadata.useFirstNameOnly }, set: onUseFirstNameOnlyChanged)) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Use first names in reports")
                            .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                        Text("Applies to generated draft text and prepared DOCX/XLSX/XLS report headings.")
                            .font(.footnote)
                            .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(CommenterStationeryTheme.Colors.localGreen)
                .disabled(isDisabled)
                .padding(.vertical, 10)
                WorklistRuledDivider()
                Button(action: onSave) {
                    WorklistActionRow(
                        title: "Save Project",
                        subtitle: lastSavedText,
                        systemImage: "square.and.arrow.down",
                        tone: .local,
                        isEnabled: !isDisabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityIdentifier("save-project-button")
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Project", step: 1, detail: "Name, class context, save status", tone: .local)
        }

        Section {
            WorklistNotebookCard(perforated: false) {
                Button(role: .destructive, action: onDeleteProject) {
                    WorklistActionRow(
                        title: "Delete Project",
                        subtitle: deleteSubtitle,
                        systemImage: "trash",
                        tone: .failure,
                        isEnabled: !isDisabled && deleteDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled || deleteDisabledReason != nil)
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Danger zone", tone: .failure)
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
            WorklistNotebookCard(clipped: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(preview.title)
                        .font(CommenterStationeryTheme.Typography.compactPageTitle)
                        .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    Text(preview.detail)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    WorklistStatusChip("\(preview.acceptedRows) accepted", systemImage: "checkmark.seal", tone: preview.acceptedRows > 0 ? .success : .warning)
                }
                if isSaving {
                    WorklistRuledDivider()
                    ProgressView("Saving confirmed import and verifying local storage")
                        .tint(CommenterStationeryTheme.Colors.localGreen)
                } else {
                    WorklistRuledDivider()
                    WorklistNote("Project data will not change until this import is confirmed and the local save verifies.")
                }
                WorklistRuledDivider()
                Button(action: onConfirm) {
                    WorklistActionRow(title: "Confirm Import", systemImage: "checkmark.circle", tone: .local, isEnabled: !isSaving, showsChevron: false)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                WorklistRuledDivider()
                Button(role: .cancel, action: onCancel) {
                    WorklistActionRow(title: "Cancel Import", systemImage: "xmark.circle", tone: .warning, isEnabled: !isSaving, showsChevron: false)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Import preview", detail: "All-or-nothing local save", tone: .warning)
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
    let onGenderChanged: (String, Gender?) -> Void
    let onPronounsChanged: (String, String) -> Void
    let onInternalNoteChanged: (String, String) -> Void
    let onAttitudeDescriptorChanged: (String, String) -> Void
    let onImportRoster: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            WorklistNotebookCard(clipped: true) {
                tabularImportStatus(importState, emptyLabel: "Roster not imported")
                WorklistRuledDivider()
                Button(action: onImportRoster) {
                    WorklistActionRow(
                        title: "Import Roster CSV, XLSX, or XLS",
                        subtitle: "Preview and confirm student names before the verified local project changes.",
                        systemImage: "square.and.arrow.down",
                        tone: .action,
                        isEnabled: !isDisabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                WorklistRuledDivider()
                Button(action: onAddStudent) {
                    WorklistActionRow(
                        title: "Add Student",
                        subtitle: "Add a student manually when a roster file is not available.",
                        systemImage: "person.badge.plus",
                        tone: .local,
                        isEnabled: !isDisabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                .accessibilityIdentifier("add-student-button")
            }
            .worklistSectionRow()
            if project.roster.isEmpty {
                WorklistEmptyCard(
                    systemImage: "person.2.badge.plus",
                    title: "No students yet",
                    message: "Add students manually or import a roster file before entering results or generating draft comments."
                )
                .worklistSectionRow()
            } else {
                if !rosterValidationMessages.isEmpty {
                    WorklistNotebookCard(perforated: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(rosterValidationMessages, id: \.self) { message in
                                WorklistNote(message, tone: .warning)
                            }
                        }
                    }
                    .worklistSectionRow()
                }
                WorklistNotebookCard {
                    ForEach(project.roster) { student in
                        NavigationLink {
                            StudentEditorView(
                                student: student,
                                isDisabled: isDisabled,
                                onFirstNameChanged: { onFirstNameChanged(student.id, $0) },
                                onLastNameChanged: { onLastNameChanged(student.id, $0) },
                                onYearChanged: { onYearChanged(student.id, $0) },
                                onGenderChanged: { onGenderChanged(student.id, $0) },
                                onPronounsChanged: { onPronounsChanged(student.id, $0) },
                                onInternalNoteChanged: { onInternalNoteChanged(student.id, $0) },
                                onAttitudeDescriptorChanged: { onAttitudeDescriptorChanged(student.id, $0) },
                                onDelete: { onDeleteStudent(student.id) }
                            )
                        } label: {
                            WorklistActionRow(
                                title: fullStudentName(student),
                                subtitle: student.yearLevel.rawValue,
                                systemImage: "person.text.rectangle",
                                tone: .local,
                                isEnabled: !isDisabled
                            )
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
                        if student.id != project.roster.last?.id {
                            WorklistRuledDivider()
                        }
                    }
                }
                .worklistSectionRow()
            }
        } header: {
            WorklistTapeHeader("Roster", step: 2, detail: "Students required before results and drafts", tone: .local)
        }
    }

    private var rosterValidationMessages: [String] {
        var messages: [String] = []
        let incompleteCount = project.roster.filter {
            $0.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                $0.lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        if incompleteCount > 0 {
            messages.append("\(incompleteCount) roster \(incompleteCount == 1 ? "entry needs" : "entries need") first and last names before results and drafts can be trusted.")
        }
        let duplicateCount = duplicateStudentDisplayKeys(roster: project.roster).count
        if duplicateCount > 0 {
            messages.append("\(duplicateCount) duplicate student \(duplicateCount == 1 ? "identity needs" : "identities need") resolving before the project can be saved cleanly.")
        }
        return messages
    }
}

private struct StudentEditorView: View {
    let student: Student
    let isDisabled: Bool
    let onFirstNameChanged: (String) -> Void
    let onLastNameChanged: (String) -> Void
    let onYearChanged: (StudentYearLevel) -> Void
    let onGenderChanged: (Gender?) -> Void
    let onPronounsChanged: (String) -> Void
    let onInternalNoteChanged: (String) -> Void
    let onAttitudeDescriptorChanged: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section {
                WorklistNotebookCard(clipped: true) {
                    WorklistFormRow(label: "First name") {
                        TextField("First name", text: Binding(get: { student.firstName }, set: onFirstNameChanged))
                            .commenterWordsTextInput()
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-first-name-\(student.id)")
                    }
                    WorklistRuledDivider()
                    WorklistFormRow(label: "Surname") {
                        TextField("Last name", text: Binding(get: { student.lastName }, set: onLastNameChanged))
                            .commenterWordsTextInput()
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-last-name-\(student.id)")
                    }
                    WorklistRuledDivider()
                    Picker("Year", selection: Binding(get: { student.yearLevel }, set: onYearChanged)) {
                        Text("Year 5").tag(StudentYearLevel.year5)
                        Text("Year 6").tag(StudentYearLevel.year6)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDisabled)
                    .padding(.top, 10)
                    WorklistRuledDivider()
                    Picker("Gender", selection: Binding(get: { student.gender ?? .unspecified }, set: { onGenderChanged($0 == .unspecified ? nil : $0) })) {
                        Text("Unspecified").tag(Gender.unspecified)
                        Text("Female").tag(Gender.female)
                        Text("Male").tag(Gender.male)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isDisabled)
                    WorklistRuledDivider()
                    WorklistFormRow(label: "Pronouns") {
                        TextField("they/them, she/her, he/him", text: Binding(get: { student.pronouns ?? "" }, set: onPronounsChanged))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-pronouns-\(student.id)")
                    }
                    WorklistRuledDivider()
                    WorklistFormRow(label: "Learner style") {
                        TextField("e.g. thoughtful, persistent", text: Binding(get: { student.attitudeDescriptor ?? "" }, set: onAttitudeDescriptorChanged))
                            .commenterWordsTextInput()
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-attitude-\(student.id)")
                    }
                    WorklistRuledDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Private teacher note")
                            .font(.caption)
                            .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                        TextEditor(text: Binding(get: { student.internalTeacherNote ?? "" }, set: onInternalNoteChanged))
                            .frame(minHeight: 96)
                            .scrollContentBackground(.hidden)
                            .background(CommenterStationeryTheme.Colors.paperSurface)
                            .commenterReportTextInput()
                            .disabled(isDisabled)
                            .accessibilityIdentifier("student-internal-note-\(student.id)")
                        WorklistNote("Private notes are stored in the local project for teacher reference. They are not inserted into generated report text.")
                    }
                }
                .worklistSectionRow()
            } header: {
                WorklistTapeHeader("Student details", tone: .neutral)
            }
            Section {
                WorklistNotebookCard(perforated: false) {
                    Button(role: .destructive, action: onDelete) {
                        WorklistActionRow(title: "Delete Student", systemImage: "trash", tone: .failure, isEnabled: !isDisabled, showsChevron: false)
                    }
                    .disabled(isDisabled)
                }
                .worklistSectionRow()
            }
        }
        .scrollContentBackground(.hidden)
        .background(CommenterStationeryTheme.Colors.paperBackground)
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
            WorklistNotebookCard(clipped: true) {
                HStack(spacing: 10) {
                    Button(action: onSelectAll) {
                        Label("Select all", systemImage: "checkmark.circle")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(CommenterStationeryTheme.Colors.localGreen)
                    .disabled(isDisabled || selectedSubjectCount == availableTeacherSubjects().count)
                    .accessibilityIdentifier("subject-select-all-button")

                    Button(role: .destructive, action: onDeselectAll) {
                        Label("Deselect all", systemImage: "xmark.circle")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .tint(CommenterStationeryTheme.Colors.attentionOrange)
                    .disabled(isDisabled || selectedSubjectCount == 0)
                    .accessibilityIdentifier("subject-deselect-all-button")
                }
                .controlSize(.regular)
                WorklistRuledDivider()
                WorklistNote("Select the curriculum areas to include in this reporting cycle. At least one subject is required before results can be imported or drafts generated.")
                WorklistRuledDivider()
                ForEach(australianCurriculumSubjectOrder) { descriptor in
                    let isSelected = project.metadata.selectedSubjects[descriptor.key] != nil
                    SubjectSelectionButton(
                        title: descriptor.displayName,
                        subtitle: descriptor.subtitle,
                        isSelected: isSelected,
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "subject-toggle-\(accessibilityKey(descriptor.key))",
                        action: { onSubjectToggled(descriptor.key) }
                    )
                    if subjectRequiresConcreteFocus(descriptor.key), project.metadata.selectedSubjects[descriptor.key] != nil {
                        WorklistNote("Specific focus required: \(getConcreteFocusOptions(descriptor.key).joined(separator: ", ")).")
                    }
                    if descriptor.key != australianCurriculumSubjectOrder.last?.key {
                        WorklistRuledDivider()
                    }
                }
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Subjects", step: 3, detail: "Australian Curriculum order", tone: .local)
        }
    }

    private var selectedSubjectCount: Int {
        selectedSubjectKeys(project.metadata.selectedSubjects).count
    }
}

private struct SubjectSelectionButton: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isDisabled: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.secondaryInk.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: isSelected ? [] : [5, 4]))
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                    }
                }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

struct ResultsSection: View {
    let project: Project
    let readiness: ProjectReadiness?
    let importState: AppFeature.TabularImportState
    let onAchievementChanged: (String, String, AchievementLevel?) -> Void
    let onFocusChanged: (String, String, String) -> Void
    let onEvidenceChanged: (String, String, String) -> Void
    let onTextTypeChanged: (String, String, String) -> Void
    let onLearningContextChanged: (String, String, String) -> Void
    let onReportEmphasisNoteChanged: (String, String, String) -> Void
    let onFlagChanged: (String, String, String, Bool) -> Void
    let onEnglishFocusTagsChanged: (String, String, [String]) -> Void
    let onMathProficienciesChanged: (String, String, [String]) -> Void
    let onMathMindsetTogglesChanged: (String, String, [String]) -> Void
    let onNextStepGoalsChanged: (String, String, [String]) -> Void
    let onImportResults: () -> Void
    let isDisabled: Bool

    var body: some View {
        Section {
            WorklistNotebookCard(clipped: true) {
                tabularImportStatus(importState, emptyLabel: "Results not imported")
                WorklistRuledDivider()
                Button(action: onImportResults) {
                    WorklistActionRow(
                        title: "Import Results CSV, XLSX, or XLS",
                        subtitle: resultsImportSubtitle,
                        systemImage: "square.and.arrow.down",
                        tone: .action,
                        isEnabled: canImportResults
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canImportResults)
                if let disabledMessage = resultsImportDisabledMessage {
                    WorklistRuledDivider()
                    WorklistNote(disabledMessage, tone: .warning)
                }
            }
            .worklistSectionRow()

            if project.roster.isEmpty || selectedSubjects.isEmpty {
                WorklistEmptyCard(
                    systemImage: "chart.bar.doc.horizontal",
                    title: "Results waiting for prerequisites",
                    message: resultsImportDisabledMessage ?? "Add students and select subjects before entering results."
                )
                .worklistSectionRow()
            } else if project.results.isEmpty {
                WorklistEmptyCard(
                    systemImage: "tray.and.arrow.down",
                    title: "No results recorded",
                    message: "Import a results file or enter achievement levels manually for each selected student and subject."
                )
                .worklistSectionRow()
            }

            ForEach(project.roster) { student in
                ForEach(selectedSubjects, id: \.self) { subject in
                    let result = project.results.first { $0.studentId == student.id && $0.subject == subject }
                    WorklistNotebookCard {
                        WorklistTapeInlineTitle("\(fullStudentName(student)) - \(displaySubjectName(subject))")
                        AchievementLevelSelector(
                            selection: result?.achievementLevel,
                            onSelectionChanged: { onAchievementChanged(student.id, subject, $0) },
                            isDisabled: isDisabled,
                            accessibilityIdentifier: "achievement-picker-\(student.id)-\(accessibilityKey(subject))"
                        )
                        if subjectRequiresConcreteFocus(subject) {
                            WorklistRuledDivider()
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
                            WorklistRuledDivider()
                            TextField("Focus", text: Binding(get: { result?.focusStrand ?? "" }, set: { onFocusChanged(student.id, subject, $0) }))
                                .commenterWordsTextInput()
                                .disabled(isDisabled)
                                .accessibilityIdentifier("focus-field-\(student.id)-\(accessibilityKey(subject))")
                        }
                        WorklistRuledDivider()
                        ResultContextFields(
                            result: result,
                            student: student,
                            studentID: student.id,
                            subject: subject,
                            projectMetadata: project.metadata,
                            isDisabled: isDisabled,
                            onEvidenceChanged: { onEvidenceChanged(student.id, subject, $0) },
                            onTextTypeChanged: { onTextTypeChanged(student.id, subject, $0) },
                            onLearningContextChanged: { onLearningContextChanged(student.id, subject, $0) },
                            onReportEmphasisNoteChanged: { onReportEmphasisNoteChanged(student.id, subject, $0) }
                        )
                        if subject.caseInsensitiveCompare("English") == .orderedSame {
                            WorklistRuledDivider()
                            LimitedOptionToggleGroup(
                                title: "English focus",
                                options: commenterEnglishFocusTags,
                                selected: result?.englishFocusTags ?? [],
                                limit: 2,
                                isDisabled: isDisabled,
                                accessibilityPrefix: "english-focus-\(student.id)-\(accessibilityKey(subject))",
                                onSelectionChanged: { onEnglishFocusTagsChanged(student.id, subject, $0) }
                            )
                        }
                        if subject.caseInsensitiveCompare("Mathematics") == .orderedSame {
                            WorklistRuledDivider()
                            LimitedOptionToggleGroup(
                                title: "Math proficiencies",
                                options: commenterMathProficiencies,
                                selected: result?.mathProficiencies ?? [],
                                limit: 2,
                                isDisabled: isDisabled,
                                accessibilityPrefix: "math-proficiency-\(student.id)-\(accessibilityKey(subject))",
                                onSelectionChanged: { onMathProficienciesChanged(student.id, subject, $0) }
                            )
                            WorklistRuledDivider()
                            LimitedOptionToggleGroup(
                                title: "Math habits",
                                options: commenterMathMindsetToggles,
                                selected: result?.mathMindsetToggles ?? [],
                                limit: nil,
                                isDisabled: isDisabled,
                                accessibilityPrefix: "math-habit-\(student.id)-\(accessibilityKey(subject))",
                                onSelectionChanged: { onMathMindsetTogglesChanged(student.id, subject, $0) }
                            )
                        }
                        WorklistRuledDivider()
                        LimitedOptionToggleGroup(
                            title: "Next steps",
                            options: commenterNextStepGoals(for: subject),
                            selected: result?.nextStepGoals ?? [],
                            limit: 2,
                            isDisabled: isDisabled,
                            accessibilityPrefix: "next-step-\(student.id)-\(accessibilityKey(subject))",
                            onSelectionChanged: { onNextStepGoalsChanged(student.id, subject, $0) }
                        )
                        WorklistRuledDivider()
                        ReportFlagToggleGroup(
                            flags: result?.flags ?? [:],
                            isDisabled: isDisabled,
                            accessibilityPrefix: "report-flag-\(student.id)-\(accessibilityKey(subject))",
                            onFlagChanged: { onFlagChanged(student.id, subject, $0, $1) }
                        )
                        if let entry = readiness?.entries.first(where: { $0.studentId == student.id && $0.subject == subject }) {
                            WorklistRuledDivider()
                            Label(entry.message, systemImage: isReadyForExport(entry.status) ? "checkmark.circle" : "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(isReadyForExport(entry.status) ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.attentionOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .worklistSectionRow()
                    .accessibilityIdentifier("result-card-\(student.id)-\(accessibilityKey(subject))")
                }
            }
        } header: {
            WorklistTapeHeader("Results", step: 4, detail: "Distinct empty, failed, zero-row, and success states", tone: .warning)
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

private struct AchievementLevelSelector: View {
    let selection: AchievementLevel?
    let onSelectionChanged: (AchievementLevel?) -> Void
    let isDisabled: Bool
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Achievement")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                .overlay(alignment: .bottomLeading) {
                    Capsule()
                        .fill(CommenterStationeryTheme.Colors.localGreen.opacity(0.35))
                        .frame(height: 2)
                        .offset(y: 4)
                }
            LazyVGrid(columns: optionColumns, alignment: .leading, spacing: 8) {
                AchievementLevelButton(
                    title: "Missing",
                    isSelected: selection == nil,
                    isDisabled: isDisabled,
                    accessibilityIdentifier: "\(accessibilityIdentifier)-missing",
                    action: { onSelectionChanged(nil) }
                )

                ForEach(achievementLevelOptions, id: \.rawValue) { level in
                    AchievementLevelButton(
                        title: level.rawValue,
                        isSelected: selection == level,
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "\(accessibilityIdentifier)-\(accessibilityKey(level.rawValue))",
                        action: { onSelectionChanged(level) }
                    )
                }
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var optionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
}

private struct AchievementLevelButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .stroke(isSelected ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.secondaryInk.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: isSelected ? [] : [5, 4]))
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? CommenterStationeryTheme.Colors.localGreenSoft : CommenterStationeryTheme.Colors.paperSurfaceDeep.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.paperLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel("Achievement \(title)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private let achievementLevelOptions: [AchievementLevel] = [
    .beginning,
    .developing,
    .atStandard,
    .aboveStandard
]

private struct ResultContextFields: View {
    let result: AchievementResult?
    let student: Student
    let studentID: String
    let subject: String
    let projectMetadata: ProjectMetadata
    let isDisabled: Bool
    let onEvidenceChanged: (String) -> Void
    let onTextTypeChanged: (String) -> Void
    let onLearningContextChanged: (String) -> Void
    let onReportEmphasisNoteChanged: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WorklistFormRow(label: "Evidence") {
                TextField("Concrete evidence for this subject", text: Binding(get: { result?.evidenceText ?? "" }, set: onEvidenceChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("result-evidence-\(studentID)-\(accessibilityKey(subject))")
            }
            if let feedback = evidenceInputFeedback(value: result?.evidenceText, student: student, subject: subject, result: feedbackResult, projectMetadata: projectMetadata) {
                WorklistFieldFeedback(feedback)
            }
            WorklistRuledDivider()
            WorklistFormRow(label: "Text type") {
                TextField("Genre, task type, or work sample", text: Binding(get: { result?.textType ?? "" }, set: onTextTypeChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("result-text-type-\(studentID)-\(accessibilityKey(subject))")
            }
            if let feedback = reportContextPhraseFeedback(value: result?.textType, label: "Text type / genre", example: "persuasive paragraph") {
                WorklistFieldFeedback(feedback)
            }
            WorklistRuledDivider()
            WorklistFormRow(label: "Context") {
                TextField("Learning activity or assessment context", text: Binding(get: { result?.learningContext ?? "" }, set: onLearningContextChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("result-learning-context-\(studentID)-\(accessibilityKey(subject))")
            }
            if let feedback = reportContextPhraseFeedback(value: result?.learningContext, label: "Learning context / activity", example: "class novel discussion") {
                WorklistFieldFeedback(feedback)
            }
            WorklistRuledDivider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Report note")
                    .font(.caption)
                    .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                TextEditor(text: Binding(get: { result?.reportEmphasisNote ?? "" }, set: onReportEmphasisNoteChanged))
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .background(CommenterStationeryTheme.Colors.paperSurface)
                    .commenterReportTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("result-report-note-\(studentID)-\(accessibilityKey(subject))")
                if let feedback = reportNoteInputFeedback(value: result?.reportEmphasisNote, student: student, subject: subject, result: feedbackResult, projectMetadata: projectMetadata) {
                    WorklistFieldFeedback(feedback)
                }
                WorklistNote("Report notes may appear in parent-facing draft comments. Use private teacher notes for information that should not be included in generated or exported report text.")
            }
        }
    }

    private var feedbackResult: AchievementResult {
        result ?? AchievementResult(studentId: studentID, subject: subject)
    }
}

private struct LimitedOptionToggleGroup: View {
    let title: String
    let options: [String]
    let selected: [String]
    let limit: Int?
    let isDisabled: Bool
    let accessibilityPrefix: String
    let onSelectionChanged: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                Spacer(minLength: 0)
                if let limit {
                    Text("\(normalizedSelection.count)/\(limit)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selectionIsAtLimit ? CommenterStationeryTheme.Colors.attentionOrange : CommenterStationeryTheme.Colors.secondaryInk)
                }
            }
            LazyVGrid(columns: optionColumns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = normalizedSelection.contains(option)
                    OptionPillButton(
                        title: option,
                        isSelected: isSelected,
                        isDisabled: isDisabled || (!isSelected && selectionIsAtLimit),
                        accessibilityIdentifier: "\(accessibilityPrefix)-\(accessibilityKey(option))",
                        action: { toggle(option) }
                    )
                }
            }
            if let limit {
                WorklistNote("Up to \(limit) selections are used in generated comments.")
            }
        }
    }

    private var normalizedSelection: [String] {
        selected.filter { options.contains($0) }
    }

    private var selectionIsAtLimit: Bool {
        guard let limit else { return false }
        return normalizedSelection.count >= limit
    }

    private var optionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private func toggle(_ option: String) {
        var next = normalizedSelection
        if let index = next.firstIndex(of: option) {
            next.remove(at: index)
        } else if limit.map({ next.count < $0 }) ?? true {
            next.append(option)
        }
        onSelectionChanged(next)
    }
}

private struct ReportFlagToggleGroup: View {
    let flags: [String: Bool]
    let isDisabled: Bool
    let accessibilityPrefix: String
    let onFlagChanged: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report flags")
                .font(.headline.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
            LazyVGrid(columns: optionColumns, alignment: .leading, spacing: 8) {
                ForEach(commenterReportFlagOptions, id: \.id) { flag in
                    OptionPillButton(
                        title: flag.label,
                        isSelected: flags[flag.id] == true,
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "\(accessibilityPrefix)-\(accessibilityKey(flag.id))",
                        action: { onFlagChanged(flag.id, flags[flag.id] != true) }
                    )
                }
            }
        }
    }

    private var optionColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }
}

private struct OptionPillButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.secondaryInk)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isSelected ? CommenterStationeryTheme.Colors.localGreenSoft : CommenterStationeryTheme.Colors.paperSurfaceDeep.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? CommenterStationeryTheme.Colors.localGreen : CommenterStationeryTheme.Colors.paperLine, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

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
            WorklistNotebookCard(clipped: true) {
                Button(action: onGenerate) {
                    WorklistActionRow(
                        title: reportGenerationButtonTitle(project: project, readiness: readiness),
                        subtitle: generationSubtitle,
                        systemImage: "text.bubble",
                        tone: .action,
                        isEnabled: canGenerate,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate)
                .accessibilityIdentifier("generate-reports-button")
                if isGenerating {
                    WorklistRuledDivider()
                    ProgressView("Generating deterministic draft comments")
                        .tint(CommenterStationeryTheme.Colors.localGreen)
                }
                if let disabledReason = generationDisabledReason {
                    WorklistRuledDivider()
                    WorklistNote(disabledReason, tone: .warning)
                }
                if readiness?.entries.contains(where: { $0.status == .staleReport || $0.status == .lockedStale }) == true {
                    WorklistRuledDivider()
                    WorklistStatusChip("Stale drafts need review", systemImage: "arrow.triangle.2.circlepath", tone: .warning)
                }
            }
            .worklistSectionRow()
            if project.reports.isEmpty {
                WorklistEmptyCard(
                    systemImage: "text.bubble",
                    title: "No draft comments yet",
                    message: "Draft comments are generated deterministically from the bundled local dataset after roster, subjects, and results are ready."
                )
                .worklistSectionRow()
            }
            if project.reports.isEmpty == false {
                WorklistNotebookCard {
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
                            WorklistActionRow(
                                title: reportTitle(report, project: project),
                                subtitle: report.isLocked ? "Locked against regeneration" : "Editable draft",
                                systemImage: report.isLocked ? "lock" : "doc.text",
                                tone: report.isLocked ? .warning : .local
                            )
                        }
                        .accessibilityIdentifier("report-row-\(report.studentId)-\(accessibilityKey(report.subject))")
                        if report.reportListIdentifier != project.reports.last?.reportListIdentifier {
                            WorklistRuledDivider()
                        }
                    }
                }
                .worklistSectionRow()
            }
        } header: {
            WorklistTapeHeader("Draft reports", step: 5, detail: "Deterministic local draft generation", tone: .action)
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
                WorklistNotebookCard(clipped: true) {
                    TextEditor(text: Binding(
                        get: { report.manualEdit ?? report.text },
                        set: onManualEditChanged
                    ))
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
                    .background(CommenterStationeryTheme.Colors.paperSurface)
                    .commenterReportTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("report-editor-\(report.studentId)-\(accessibilityKey(report.subject))")
                    if let feedback = reportEditorFeedback {
                        WorklistFieldFeedback(feedback)
                    }
                    WorklistRuledDivider()
                    Toggle("Lock against regeneration", isOn: Binding(get: { report.isLocked }, set: onLockChanged))
                        .tint(CommenterStationeryTheme.Colors.localGreen)
                        .disabled(isDisabled)
                }
                .worklistSectionRow()
            } header: {
                WorklistTapeHeader("Draft text", tone: .action)
            } footer: {
                Text("Locked drafts are preserved during regeneration. Unlocked stale drafts can be regenerated from current results and selected subjects.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollContentBackground(.hidden)
        .background(CommenterStationeryTheme.Colors.paperBackground)
        .navigationTitle(reportTitle(report, project: project))
        .commenterInlineNavigationTitle()
    }

    private var reportEditorFeedback: ReportInputFeedback? {
        let text = report.manualEdit ?? report.text
        let placeholders = findUnresolvedPlaceholders(text)
        if let placeholder = placeholders.first {
            return ReportInputFeedback(
                tone: .error,
                message: "This draft contains template text that must be replaced before export.",
                detail: "First unresolved placeholder: \(placeholder)"
            )
        }
        guard let student = project.roster.first(where: { $0.id == report.studentId }),
              let result = project.results.first(where: { $0.studentId == report.studentId && $0.subject == report.subject })
        else {
            return nil
        }
        let context = buildPlaceholderContext(student: student, subject: report.subject, result: result, projectMetadata: project.metadata)
        let lint = lintReportLanguage(
            text,
            displayName: context.displayName,
            firstName: student.firstName,
            expectedSubjectPronoun: context.heShe
        )
        if let issue = firstBlockingLanguageIssue(lint) {
            return ReportInputFeedback(
                tone: .error,
                message: issue.message,
                detail: issue.suggestion ?? issue.excerpt
            )
        }
        if let warning = lint.issues.first(where: { $0.severity == .warning }) {
            return ReportInputFeedback(
                tone: .warning,
                message: warning.message,
                detail: warning.suggestion ?? warning.excerpt
            )
        }
        return nil
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
            WorklistNotebookCard(clipped: true) {
                ForEach([ImportExportFormat.docx, .xlsx, .xls], id: \.self) { format in
                    Button { onPrepareExport(format) } label: {
                        WorklistActionRow(
                            title: format.prepareTitle,
                            subtitle: exportSubtitle(for: format),
                            systemImage: format.exportSystemImage,
                            tone: .action,
                            isEnabled: !isDisabled && canPrepareReports
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isDisabled || !canPrepareReports)
                    .accessibilityIdentifier(format == .docx ? "prepare-docx-reports-button" : "prepare-\(format.rawValue)-reports-button")
                    if format != .xls {
                        WorklistRuledDivider()
                    }
                }
                if isDisabled {
                    WorklistRuledDivider()
                    WorklistNote(disabledReason ?? "Report export preparation is paused until the current project state is available.", tone: .warning)
                } else if !canPrepareReports {
                    WorklistRuledDivider()
                    WorklistNote(exportBlockedMessage, tone: .warning)
                }
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Reports", step: 6, detail: "Prepare delivery files after every draft is ready", tone: .action)
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
            WorklistNotebookCard {
                Button(action: onPrepareBackup) {
                    WorklistActionRow(
                        title: "Prepare Backup JSON",
                        subtitle: backupSubtitle,
                        systemImage: "externaldrive.badge.checkmark",
                        tone: .local,
                        isEnabled: !isDisabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
                if isDisabled {
                    WorklistRuledDivider()
                    WorklistNote(disabledReason ?? "Backup preparation is paused until the current project state is available.", tone: .warning)
                }
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("Backup", step: 7, detail: "User-owned recovery copy", tone: .local)
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
                WorklistNotebookCard(clipped: true) {
                    if hasHiddenStalePreparedFile {
                        WorklistStatusChip("Prepared file hidden until current edits are saved", systemImage: "exclamationmark.triangle", tone: .warning)
                        WorklistRuledDivider()
                        WorklistNote("Save the project and prepare a new file so exports and shares reflect verified local state.", tone: .warning)
                    }
                    if let preparedFile {
                        if hasHiddenStalePreparedFile {
                            WorklistRuledDivider()
                        }
                        Label("Verified prepared file is ready", systemImage: "checkmark.seal")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                            .accessibilityIdentifier("prepared-file-ready")
                        WorklistRuledDivider()
                        LabeledContent("Prepared file", value: preparedFile.url.lastPathComponent)
                        Text(preparedFile.label)
                            .font(.footnote)
                            .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                        if let preparedAt = preparedFile.preparedAtMilliseconds {
                            WorklistRuledDivider()
                            LabeledContent("Prepared", value: CommenterFormatters.timestamp(preparedAt))
                        }
                    }
                }
                .worklistSectionRow()
                if preparedFile != nil {
                    WorklistNotebookCard(perforated: false) {
                        Button(action: onSavePreparedFile) {
                            WorklistActionRow(title: "Save Prepared File Copy", systemImage: "square.and.arrow.down", tone: .local, isEnabled: !isDisabled)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                        WorklistRuledDivider()
                        Button(action: onSharePreparedFile) {
                            WorklistActionRow(title: "Share Prepared File", systemImage: "square.and.arrow.up", tone: .action, isEnabled: !isDisabled)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                        WorklistRuledDivider()
                        WorklistNote("This file has been prepared and verified locally. Saving reports success only after the file exporter returns; sharing records completed, cancelled, or failed native share outcomes.")
                        WorklistRuledDivider()
                        Button(action: onDismissPreparedFile) {
                            WorklistActionRow(title: "Dismiss Prepared File", systemImage: "xmark", tone: .neutral, isEnabled: !isDisabled, showsChevron: false)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled)
                    }
                    .worklistSectionRow()
                }
            } header: {
                WorklistTapeHeader("Prepared file", detail: "Verified file ready for native save or share", tone: .prepared)
            }
        }
    }
}

@ViewBuilder
private func tabularImportStatus(_ state: AppFeature.TabularImportState, emptyLabel: String) -> some View {
    switch state {
    case .neverImported:
        WorklistStatusChip(emptyLabel, systemImage: "tray", tone: .neutral)
    case let .loaded(count, source):
        WorklistStatusChip("Loaded \(count) rows from \(source)", systemImage: "checkmark.seal", tone: .success)
    case let .validating(source):
        HStack {
            ProgressView()
            Text("Validating \(source)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(CommenterStationeryTheme.Colors.paperSurfaceDeep))
        .accessibilityElement(children: .combine)
    case let .previewReady(count, source):
        WorklistStatusChip("Preview ready: \(count) rows from \(source)", systemImage: "doc.text.magnifyingglass", tone: .prepared)
    case let .zeroValidRecords(message):
        WorklistStatusChip(message, systemImage: "0.circle", tone: .warning)
    case let .failed(message):
        WorklistStatusChip(message, systemImage: "exclamationmark.triangle", tone: .failure)
    case let .success(count, source):
        WorklistStatusChip("Imported \(count) rows from \(source)", systemImage: "checkmark.seal", tone: .success)
    case let .stale(message):
        WorklistStatusChip(message, systemImage: "arrow.triangle.2.circlepath", tone: .warning)
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

private enum WorklistTone: Equatable {
    case neutral
    case local
    case success
    case warning
    case failure
    case prepared
    case action

    var stationeryTone: StationeryTone {
        switch self {
        case .neutral:
            return .neutral
        case .local:
            return .local
        case .success:
            return .success
        case .warning:
            return .warning
        case .failure:
            return .failure
        case .prepared:
            return .prepared
        case .action:
            return .action
        }
    }

    var color: Color {
        stationeryTone.color
    }

    var softColor: Color {
        stationeryTone.softColor
    }
}

private struct WorklistTapeHeader: View {
    let title: String
    let step: Int?
    let detail: String?
    let tone: WorklistTone

    init(_ title: String, step: Int? = nil, detail: String? = nil, tone: WorklistTone = .neutral) {
        self.title = title
        self.step = step
        self.detail = detail
        self.tone = tone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let step {
                Text("\(step)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 27, height: 27)
                    .background(Circle().fill(tone.color))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                TapeLabel(title, tone: tone.stationeryTone)
                if let detail, !detail.isEmpty {
                    HandwrittenAnnotation(detail)
                }
            }
            Spacer(minLength: 0)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct WorklistNotebookCard<Content: View>: View {
    let perforated: Bool
    let clipped: Bool
    let content: Content

    init(perforated: Bool = true, clipped: Bool = false, @ViewBuilder content: () -> Content) {
        self.perforated = perforated
        self.clipped = clipped
        self.content = content()
    }

    var body: some View {
        NotebookCard(
            showsPerforation: perforated,
            showsPaperclip: clipped,
            showsStack: true
        ) {
            content
        }
    }
}

private struct WorklistRuledDivider: View {
    var body: some View {
        Divider()
            .overlay(CommenterStationeryTheme.Colors.paperLine)
            .padding(.vertical, 10)
            .accessibilityHidden(true)
    }
}

private struct WorklistFormRow<Content: View>: View {
    let systemImage: String?
    let label: String?
    let content: Content

    init(systemImage: String? = nil, label: String? = nil, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let systemImage {
                StatusIconBubble(systemImage: systemImage, tone: .local)
                    .scaleEffect(0.72)
                    .frame(width: 30, height: 30)
            }
            if let label {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                    .frame(width: 86, alignment: .leading)
            }
            content
                .font(.body)
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
        }
        .frame(minHeight: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorklistActionRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let tone: WorklistTone
    let isEnabled: Bool
    let showsChevron: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tone: WorklistTone = .action,
        isEnabled: Bool = true,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.isEnabled = isEnabled
        self.showsChevron = showsChevron
    }

    var body: some View {
        StationeryActionRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tone: tone.stationeryTone,
            isEnabled: isEnabled,
            showsChevron: showsChevron
        )
    }
}

private struct WorklistStatusChip: View {
    let text: String
    let systemImage: String
    let tone: WorklistTone

    init(_ text: String, systemImage: String, tone: WorklistTone = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    var body: some View {
        StationeryStatusChip(text, systemImage: systemImage, tone: tone.stationeryTone)
    }
}

private struct WorklistNote: View {
    let text: String
    let tone: WorklistTone

    init(_ text: String, tone: WorklistTone = .neutral) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(tone == .warning ? CommenterStationeryTheme.Colors.attentionOrange : CommenterStationeryTheme.Colors.secondaryInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorklistFieldFeedback: View {
    let feedback: ReportInputFeedback

    init(_ feedback: ReportInputFeedback) {
        self.feedback = feedback
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = feedback.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }

    private var systemImage: String {
        switch feedback.tone {
        case .error:
            return "exclamationmark.triangle"
        case .warning:
            return "exclamationmark.circle"
        case .success:
            return "checkmark.circle"
        }
    }

    private var color: Color {
        switch feedback.tone {
        case .error:
            return CommenterStationeryTheme.Colors.destructiveRed
        case .warning:
            return CommenterStationeryTheme.Colors.attentionOrange
        case .success:
            return CommenterStationeryTheme.Colors.localGreen
        }
    }

    private var background: Color {
        switch feedback.tone {
        case .error:
            return CommenterStationeryTheme.Colors.destructiveRed.opacity(0.08)
        case .warning:
            return CommenterStationeryTheme.Colors.attentionOrange.opacity(0.1)
        case .success:
            return CommenterStationeryTheme.Colors.localGreenSoft
        }
    }
}

private struct WorklistEmptyCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        StationeryEmptyState(systemImage: systemImage, title: title, message: message)
    }
}

private struct WorklistTapeInlineTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        TapeLabel(title)
            .padding(.bottom, 12)
            .accessibilityAddTraits(.isHeader)
    }
}

private extension View {
    func worklistSectionRow() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
