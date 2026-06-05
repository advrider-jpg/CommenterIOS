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
                    studentIdentityFields
                    WorklistRuledDivider()
                    studentPersonalFields
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
        .accessibilityIdentifier("student-editor-\(student.id)")
    }

    @ViewBuilder private var studentIdentityFields: some View {
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
    }

    @ViewBuilder private var studentPersonalFields: some View {
        WorklistFormRow(label: "Pronouns") {
            TextField("they/them, she/her, he/him", text: Binding(get: { student.pronouns ?? "" }, set: onPronounsChanged))
                .commenterUncapitalizedTextInput()
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
    let aiAvailabilityStatus: AppFeature.AIAvailabilityStatus
    let operationStatus: AppFeature.OperationStatus
    let pendingAIRevision: AppFeature.PendingAIRevision?
    let pendingAIRevisions: [AppFeature.PendingAIRevision]
    let isBulkAIRevisionRunning: Bool
    let latestReportCheck: AppFeature.ReportCheckResult?
    let isGenerating: Bool
    let onGenerate: () -> Void
    let onManualEditChanged: (String, String, String) -> Void
    let onLockChanged: (String, String, Bool) -> Void
    let onApproveReportForExport: (String, String) -> Void
    let onAIPolishReport: (String, String) -> Void
    let onAIToneAdjustReport: (String, String) -> Void
    let onAIDraftFromEvidenceReport: (String, String) -> Void
    let onBulkAIPolishReports: () -> Void
    let onCancelBulkAIPolish: () -> Void
    let onAcceptAIRevision: (String, String) -> Void
    let onRejectAIRevision: (String, String) -> Void
    let onLocalSafetyCheck: (String, String) -> Void
    let onValidationWarningsReviewed: (String, String) -> Void
    let onAICritiqueReport: (String, String) -> Void
    let onAIToneProfileChanged: (AIToneProfile) -> Void
    let onAITargetLengthChanged: (ReportLengthTarget) -> Void
    let onAICustomInstructionChanged: (String) -> Void
    let onAIForbiddenMentionsChanged: ([String]) -> Void
    let onAIRequiredMentionsChanged: ([String]) -> Void
    let onAISettingsResetBalanced: () -> Void
    let onReportAIToneProfileChanged: (String, String, AIToneProfile) -> Void
    let onReportAITargetLengthChanged: (String, String, ReportLengthTarget) -> Void
    let onReportAICustomInstructionChanged: (String, String, String) -> Void
    let onReportAIForbiddenMentionsChanged: (String, String, [String]) -> Void
    let onReportAIRequiredMentionsChanged: (String, String, [String]) -> Void
    let onReportAIOptionsSavedAsProjectDefaults: (String, String) -> Void
    let onReportAIOptionsReset: (String, String) -> Void
    let isDisabled: Bool

    @State private var isBulkAIConfirmationPresented = false

    var body: some View {
        Section {
            WorklistNotebookCard(clipped: true) {
                AIAvailabilityCard(status: aiAvailabilityStatus)
                WorklistRuledDivider()
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
                WorklistRuledDivider()
                Button {
                    isBulkAIConfirmationPresented = true
                } label: {
                    WorklistActionRow(
                        title: "Improve Eligible Drafts with AI",
                        subtitle: bulkAIDisabledReason ?? "Queues teacher-review previews for unlocked drafts. Nothing is applied or approved automatically.",
                        systemImage: "sparkles.rectangle.stack",
                        tone: .action,
                        isEnabled: bulkAIDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(bulkAIDisabledReason != nil)
                .accessibilityIdentifier("bulk-ai-polish-reports-button")
                .confirmationDialog(
                    "Queue Bulk AI Previews?",
                    isPresented: $isBulkAIConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button("Queue \(bulkAIEligibleCount) AI Preview\(bulkAIEligibleCount == 1 ? "" : "s")") {
                        onBulkAIPolishReports()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The app will request on-device AI revisions sequentially for eligible unlocked drafts. Completed previews wait for teacher review and do not approve, save, export, or share report text.")
                }
                if isBulkAIRevisionRunning {
                    WorklistRuledDivider()
                    Button(action: onCancelBulkAIPolish) {
                        WorklistActionRow(
                            title: "Cancel Bulk AI",
                            subtitle: "Stops queued AI requests. Completed previews stay available; draft text is not changed.",
                            systemImage: "xmark.circle",
                            tone: .warning,
                            isEnabled: true,
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cancel-bulk-ai-polish-button")
                }
                if !pendingReviewQueue.isEmpty {
                    WorklistRuledDivider()
                    WorklistStatusChip("\(pendingReviewQueue.count) AI preview \(pendingReviewQueue.count == 1 ? "waiting" : "waiting")", systemImage: "doc.text.magnifyingglass", tone: .prepared)
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
            if !pendingReviewQueue.isEmpty {
                WorklistNotebookCard {
                    ForEach(pendingReviewQueue) { pending in
                        if let report = report(for: pending) {
                            NavigationLink {
                                reportEditorView(report: report, pendingRevision: pending)
                            } label: {
                                WorklistActionRow(
                                    title: reportTitle(report, project: project),
                                    subtitle: reviewQueueSubtitle(pending),
                                    systemImage: pending.validation.status == .blocked ? "exclamationmark.triangle" : "doc.text.magnifyingglass",
                                    tone: pending.validation.status == .blocked ? .warning : .prepared
                                )
                            }
                            .accessibilityIdentifier("ai-review-queue-row-\(pending.studentId)-\(accessibilityKey(pending.subject))")
                        } else {
                            WorklistActionRow(
                                title: "\(pending.studentId) / \(pending.subject)",
                                subtitle: "Preview can no longer be matched to an open draft. Reject or regenerate after reviewing the project state.",
                                systemImage: "exclamationmark.triangle",
                                tone: .warning,
                                isEnabled: false,
                                showsChevron: false
                            )
                            .accessibilityIdentifier("ai-review-queue-stale-\(pending.studentId)-\(accessibilityKey(pending.subject))")
                        }
                        if pending.id != pendingReviewQueue.last?.id {
                            WorklistRuledDivider()
                        }
                    }
                }
                .worklistSectionRow()
            }
            if project.reports.isEmpty == false {
                WorklistNotebookCard {
                    ForEach(project.reports, id: \.reportListIdentifier) { report in
                        NavigationLink {
                            reportEditorView(report: report, pendingRevision: pendingRevision(for: report))
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

    private var bulkAIDisabledReason: String? {
        if isDisabled { return "Wait for the current operation or import preview to finish before requesting AI previews." }
        if isBulkAIRevisionRunning { return "Bulk AI revision is already running." }
        if case .busy = operationStatus { return "Wait for the current workflow operation to finish." }
        if pendingAIRevision != nil || !pendingAIRevisions.isEmpty { return "Accept or reject waiting AI previews before starting another bulk request." }
        switch aiAvailabilityStatus {
        case .checked(.available):
            break
        case .notChecked:
            return "On-device AI has not been checked yet."
        case .checking:
            return "On-device AI availability is still being checked."
        case let .checked(.unavailable(reason)):
            return "On-device AI is unavailable: \(reason.rawValue)."
        case let .failed(message):
            return "On-device AI availability failed: \(message)"
        }
        return bulkAIEligibleCount == 0 ? "No unlocked draft reports are eligible for AI revision." : nil
    }

    private var bulkAIEligibleCount: Int {
        project.reports.filter {
            !$0.isLocked && !$0.exportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
    }

    private func pendingRevision(for report: GeneratedReport) -> AppFeature.PendingAIRevision? {
        guard let pendingAIRevision,
              pendingAIRevision.studentId == report.studentId,
              pendingAIRevision.subject == report.subject
        else {
            return pendingAIRevisions.first { $0.studentId == report.studentId && $0.subject == report.subject }
        }
        return pendingAIRevision
    }

    private var pendingReviewQueue: [AppFeature.PendingAIRevision] {
        var queue = pendingAIRevisions
        if let pendingAIRevision,
           !queue.contains(where: { $0.studentId == pendingAIRevision.studentId && $0.subject == pendingAIRevision.subject }) {
            queue.insert(pendingAIRevision, at: 0)
        }
        return queue
    }

    private func report(for pending: AppFeature.PendingAIRevision) -> GeneratedReport? {
        project.reports.first { $0.studentId == pending.studentId && $0.subject == pending.subject }
    }

    private func reviewQueueSubtitle(_ pending: AppFeature.PendingAIRevision) -> String {
        let status: String
        switch pending.validation.status {
        case .passed:
            status = "Validation passed"
        case .passedWithWarnings:
            status = "Validation warnings"
        case .blocked:
            status = "Validation blockers"
        }
        return "\(status). Review, accept, or reject this AI preview."
    }

    private func reportEditorView(report: GeneratedReport, pendingRevision: AppFeature.PendingAIRevision?) -> ReportEditorView {
        ReportEditorView(
            report: report,
            project: project,
            aiAvailabilityStatus: aiAvailabilityStatus,
            operationStatus: operationStatus,
            pendingAIRevision: pendingRevision,
            latestReportCheck: reportCheck(for: report),
            isDisabled: isDisabled,
            onManualEditChanged: { onManualEditChanged(report.studentId, report.subject, $0) },
            onLockChanged: { onLockChanged(report.studentId, report.subject, $0) },
            onApproveForExport: { onApproveReportForExport(report.studentId, report.subject) },
            onAIPolish: { onAIPolishReport(report.studentId, report.subject) },
            onAIToneAdjust: { onAIToneAdjustReport(report.studentId, report.subject) },
            onAIDraftFromEvidence: { onAIDraftFromEvidenceReport(report.studentId, report.subject) },
            onAcceptAIRevision: { onAcceptAIRevision(report.studentId, report.subject) },
            onRejectAIRevision: { onRejectAIRevision(report.studentId, report.subject) },
            onLocalSafetyCheck: { onLocalSafetyCheck(report.studentId, report.subject) },
            onValidationWarningsReviewed: { onValidationWarningsReviewed(report.studentId, report.subject) },
            onAICritique: { onAICritiqueReport(report.studentId, report.subject) },
            onAIToneProfileChanged: onAIToneProfileChanged,
            onAITargetLengthChanged: onAITargetLengthChanged,
            onAICustomInstructionChanged: onAICustomInstructionChanged,
            onAIForbiddenMentionsChanged: onAIForbiddenMentionsChanged,
            onAIRequiredMentionsChanged: onAIRequiredMentionsChanged,
            onAISettingsResetBalanced: onAISettingsResetBalanced,
            onReportAIToneProfileChanged: { onReportAIToneProfileChanged(report.studentId, report.subject, $0) },
            onReportAITargetLengthChanged: { onReportAITargetLengthChanged(report.studentId, report.subject, $0) },
            onReportAICustomInstructionChanged: { onReportAICustomInstructionChanged(report.studentId, report.subject, $0) },
            onReportAIForbiddenMentionsChanged: { onReportAIForbiddenMentionsChanged(report.studentId, report.subject, $0) },
            onReportAIRequiredMentionsChanged: { onReportAIRequiredMentionsChanged(report.studentId, report.subject, $0) },
            onReportAIOptionsSavedAsProjectDefaults: { onReportAIOptionsSavedAsProjectDefaults(report.studentId, report.subject) },
            onReportAIOptionsReset: { onReportAIOptionsReset(report.studentId, report.subject) }
        )
    }

    private func reportCheck(for report: GeneratedReport) -> AppFeature.ReportCheckResult? {
        guard let latestReportCheck,
              latestReportCheck.studentId == report.studentId,
              latestReportCheck.subject == report.subject
        else {
            return nil
        }
        return latestReportCheck
    }
}

private struct ReportEditorView: View {
    let report: GeneratedReport
    let project: Project
    let aiAvailabilityStatus: AppFeature.AIAvailabilityStatus
    let operationStatus: AppFeature.OperationStatus
    let pendingAIRevision: AppFeature.PendingAIRevision?
    let latestReportCheck: AppFeature.ReportCheckResult?
    let isDisabled: Bool
    let onManualEditChanged: (String) -> Void
    let onLockChanged: (Bool) -> Void
    let onApproveForExport: () -> Void
    let onAIPolish: () -> Void
    let onAIToneAdjust: () -> Void
    let onAIDraftFromEvidence: () -> Void
    let onAcceptAIRevision: () -> Void
    let onRejectAIRevision: () -> Void
    let onLocalSafetyCheck: () -> Void
    let onValidationWarningsReviewed: () -> Void
    let onAICritique: () -> Void
    let onAIToneProfileChanged: (AIToneProfile) -> Void
    let onAITargetLengthChanged: (ReportLengthTarget) -> Void
    let onAICustomInstructionChanged: (String) -> Void
    let onAIForbiddenMentionsChanged: ([String]) -> Void
    let onAIRequiredMentionsChanged: ([String]) -> Void
    let onAISettingsResetBalanced: () -> Void
    let onReportAIToneProfileChanged: (AIToneProfile) -> Void
    let onReportAITargetLengthChanged: (ReportLengthTarget) -> Void
    let onReportAICustomInstructionChanged: (String) -> Void
    let onReportAIForbiddenMentionsChanged: ([String]) -> Void
    let onReportAIRequiredMentionsChanged: ([String]) -> Void
    let onReportAIOptionsSavedAsProjectDefaults: () -> Void
    let onReportAIOptionsReset: () -> Void

    var body: some View {
        Form {
            Section {
                WorklistNotebookCard(clipped: true) {
                    aiReviewStatus
                    if report.requiresTeacherApprovalForExport {
                        WorklistRuledDivider()
                    }
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
                    if report.requiresTeacherApprovalForExport {
                        WorklistRuledDivider()
                        Button(action: onApproveForExport) {
                            WorklistActionRow(
                                title: "Approve Current AI Draft for Export",
                                subtitle: "Runs deterministic validation and records teacher approval in the local project.",
                                systemImage: "checkmark.seal",
                                tone: .local,
                                isEnabled: !isDisabled && canApproveAIReport,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled || !canApproveAIReport)
                    }
                }
                .worklistSectionRow()
            } header: {
                WorklistTapeHeader("Draft text", tone: .action)
            } footer: {
                Text("Locked drafts are preserved during regeneration. Unlocked stale drafts can be regenerated from current results and selected subjects.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            aiStudioSection
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

    @ViewBuilder private var aiReviewStatus: some View {
        if report.requiresTeacherApprovalForExport {
            let currentFingerprint = stableTextFingerprint(report.exportText)
            let approved = report.reviewState?.status == .approved &&
                report.reviewState?.approvalFingerprint == currentFingerprint &&
                report.approvedTextFingerprint == currentFingerprint
            if approved {
                WorklistStatusChip("AI draft approved for export", systemImage: "checkmark.seal", tone: .success)
            } else if report.lastValidation?.status == .blocked {
                WorklistStatusChip("AI draft blocked by validation", systemImage: "exclamationmark.triangle", tone: .failure)
            } else {
                WorklistStatusChip("AI draft needs teacher review", systemImage: "person.crop.circle.badge.checkmark", tone: .warning)
            }
            if let finding = report.lastValidation?.findings.first {
                WorklistNote(finding.message, tone: finding.severity == .block ? .warning : .neutral)
            }
        }
    }

    private var canApproveAIReport: Bool {
        guard report.requiresTeacherApprovalForExport else { return false }
        return report.lastValidation?.status != .blocked
    }

    private var aiStudioSection: some View {
        Section {
            WorklistNotebookCard(clipped: true) {
                AIAvailabilityCard(status: aiAvailabilityStatus)
                WorklistRuledDivider()
                AIToneControls(
                    title: "Project AI defaults",
                    settings: project.metadata.aiSettings ?? ProjectAISettings(),
                    hasStoredSettings: project.metadata.aiSettings != nil,
                    isDisabled: isDisabled || isAIWorkflowBusy,
                    onToneProfileChanged: onAIToneProfileChanged,
                    onTargetLengthChanged: onAITargetLengthChanged,
                    onCustomInstructionChanged: onAICustomInstructionChanged,
                    onForbiddenMentionsChanged: onAIForbiddenMentionsChanged,
                    onRequiredMentionsChanged: onAIRequiredMentionsChanged,
                    onResetBalanced: onAISettingsResetBalanced
                )
                WorklistRuledDivider()
                AIReportOptionControls(
                    options: effectiveReportOptions,
                    hasOverride: report.aiOptionsOverride != nil,
                    isDisabled: isDisabled || isAIWorkflowBusy,
                    onToneProfileChanged: onReportAIToneProfileChanged,
                    onTargetLengthChanged: onReportAITargetLengthChanged,
                    onCustomInstructionChanged: onReportAICustomInstructionChanged,
                    onForbiddenMentionsChanged: onReportAIForbiddenMentionsChanged,
                    onRequiredMentionsChanged: onReportAIRequiredMentionsChanged,
                    onSaveAsProjectDefaults: onReportAIOptionsSavedAsProjectDefaults,
                    onReset: onReportAIOptionsReset
                )
                WorklistRuledDivider()
                Button(action: onAIPolish) {
                    WorklistActionRow(
                        title: "Improve with On-device AI",
                        subtitle: aiPolishDisabledReason ?? "Creates a teacher-review preview. It does not overwrite, approve, save, prepare, export, or share the draft.",
                        systemImage: "sparkles",
                        tone: .action,
                        isEnabled: aiPolishDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiPolishDisabledReason != nil)
                .accessibilityIdentifier("ai-polish-report-\(report.studentId)-\(accessibilityKey(report.subject))")
                WorklistRuledDivider()
                Button(action: onAIToneAdjust) {
                    WorklistActionRow(
                        title: "Adjust Tone with On-device AI",
                        subtitle: aiToneAdjustDisabledReason ?? "Creates a teacher-review preview that changes tone only. It does not overwrite, approve, save, prepare, export, or share the draft.",
                        systemImage: "slider.horizontal.3",
                        tone: .action,
                        isEnabled: aiToneAdjustDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiToneAdjustDisabledReason != nil)
                .accessibilityIdentifier("ai-tone-adjust-report-\(report.studentId)-\(accessibilityKey(report.subject))")
                WorklistRuledDivider()
                Button(action: onAIDraftFromEvidence) {
                    WorklistActionRow(
                        title: "Draft from Evidence with AI",
                        subtitle: aiEvidenceDraftDisabledReason ?? "Creates a teacher-review preview from report-safe evidence. It does not overwrite, approve, save, prepare, export, or share the draft.",
                        systemImage: "doc.badge.gearshape",
                        tone: .action,
                        isEnabled: aiEvidenceDraftDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiEvidenceDraftDisabledReason != nil)
                .accessibilityIdentifier("ai-draft-evidence-report-\(report.studentId)-\(accessibilityKey(report.subject))")
                WorklistRuledDivider()
                Button(action: onLocalSafetyCheck) {
                    WorklistActionRow(
                        title: "Run Local Safety Check",
                        subtitle: "Recomputes deterministic validators and stores the finding record locally. No model is required.",
                        systemImage: "checkmark.shield",
                        tone: .local,
                        isEnabled: !isDisabled && !isAIWorkflowBusy,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(isDisabled || isAIWorkflowBusy)
                .accessibilityIdentifier("local-safety-check-\(report.studentId)-\(accessibilityKey(report.subject))")
                WorklistRuledDivider()
                Button(action: onAICritique) {
                    WorklistActionRow(
                        title: "Run AI Critique",
                        subtitle: aiCritiqueDisabledReason ?? "Asks on-device AI for teacher-review notes. It does not rewrite or approve the draft.",
                        systemImage: "text.magnifyingglass",
                        tone: .action,
                        isEnabled: aiCritiqueDisabledReason == nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
                .disabled(aiCritiqueDisabledReason != nil)
                .accessibilityIdentifier("ai-critique-report-\(report.studentId)-\(accessibilityKey(report.subject))")
                if isAIWorkflowBusy {
                    WorklistRuledDivider()
                    ProgressView("Waiting for AI workflow to finish")
                        .tint(CommenterStationeryTheme.Colors.localGreen)
                }
                if let pendingAIRevision {
                    WorklistRuledDivider()
                    AIRevisionPreviewCard(
                        pendingRevision: pendingAIRevision,
                        isDisabled: isDisabled || isAIWorkflowBusy,
                        onAccept: onAcceptAIRevision,
                        onReject: onRejectAIRevision
                    )
                }
                if let latestReportCheck {
                    WorklistRuledDivider()
                    ReportValidationSummaryCard(title: "Latest local check", validation: latestReportCheck.validation, notes: latestReportCheck.reviewNotes)
                    if latestWarningsReviewed {
                        WorklistStatusChip("Warnings reviewed for this draft", systemImage: "checkmark.seal", tone: .success)
                    } else if canReviewWarnings {
                        Button(action: onValidationWarningsReviewed) {
                            WorklistActionRow(
                                title: "Mark Warnings Reviewed",
                                subtitle: "Records that the teacher reviewed the warning-only findings for the current draft.",
                                systemImage: "checkmark.seal",
                                tone: .local,
                                isEnabled: !isDisabled && !isAIWorkflowBusy,
                                showsChevron: false
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isDisabled || isAIWorkflowBusy)
                    }
                }
            }
            .worklistSectionRow()
        } header: {
            WorklistTapeHeader("AI Studio", detail: "Local, preview-first, teacher-approved", tone: .action)
        } footer: {
            Text("AI revisions are blocked unless Apple on-device AI is available. Accepted AI text remains unapproved until the teacher runs approval for the current draft.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var isAIWorkflowBusy: Bool {
        if case .busy = operationStatus { return true }
        return false
    }

    private var aiPolishDisabledReason: String? {
        if let common = commonAIDisabledReason(actionName: "AI revision") { return common }
        if (report.manualEdit ?? report.text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Draft text is required before AI can revise it."
        }
        return nil
    }

    private var aiToneAdjustDisabledReason: String? {
        if let common = commonAIDisabledReason(actionName: "AI tone adjustment") { return common }
        if (report.manualEdit ?? report.text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Draft text is required before AI can adjust its tone."
        }
        return nil
    }

    private var aiEvidenceDraftDisabledReason: String? {
        if let common = commonAIDisabledReason(actionName: "AI evidence draft") { return common }
        if reportSafeEvidenceFacts.isEmpty {
            return "Add report-safe evidence, learning context, or a report emphasis note before requesting an AI evidence draft."
        }
        return nil
    }

    private var aiCritiqueDisabledReason: String? {
        if let common = commonAIDisabledReason(actionName: "AI critique") { return common }
        if (report.manualEdit ?? report.text).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Draft text is required before AI can critique it."
        }
        return nil
    }

    private func commonAIDisabledReason(actionName: String) -> String? {
        if isDisabled { return "Finish the current local operation or import preview before requesting \(actionName)." }
        if isAIWorkflowBusy { return "Wait for the current AI workflow to finish." }
        if report.isLocked { return "Unlock this draft before requesting \(actionName)." }
        if pendingAIRevision != nil { return "Accept or reject the current AI preview before requesting another AI draft." }
        switch aiAvailabilityStatus {
        case .checked(.available):
            return nil
        case .notChecked:
            return "On-device AI has not been checked yet."
        case .checking:
            return "On-device AI availability is still being checked."
        case let .checked(.unavailable(reason)):
            return "On-device AI is unavailable: \(reason.rawValue)."
        case let .failed(message):
            return "On-device AI availability failed: \(message)"
        }
    }

    private var reportSafeEvidenceFacts: [ReportSafeFact] {
        guard let result = project.results.first(where: { $0.studentId == report.studentId && $0.subject == report.subject }) else {
            return []
        }
        return reportSafeFacts(project: project, result: result, report: report)
            .filter { $0.source != .deterministicDraft && $0.approvedForPrompt && $0.sensitivity == .reportSafe }
    }

    private var effectiveReportOptions: AIReportOptions {
        report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
    }

    private var canReviewWarnings: Bool {
        latestReportCheck?.validation.status == .passedWithWarnings
    }

    private var latestWarningsReviewed: Bool {
        guard let latestReportCheck else { return false }
        return report.validationWarningReview?.validationFingerprint == latestReportCheck.validation.textFingerprint
    }
}

private struct AIToneControls: View {
    let title: String
    let settings: ProjectAISettings
    let hasStoredSettings: Bool
    let isDisabled: Bool
    let onToneProfileChanged: (AIToneProfile) -> Void
    let onTargetLengthChanged: (ReportLengthTarget) -> Void
    let onCustomInstructionChanged: (String) -> Void
    let onForbiddenMentionsChanged: ([String]) -> Void
    let onRequiredMentionsChanged: ([String]) -> Void
    let onResetBalanced: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
            tonePicker("Voice", selection: settings.defaultToneProfile.schoolVoice, values: SchoolVoice.allCases, label: schoolVoiceLabel) { value in
                var profile = settings.defaultToneProfile
                profile.schoolVoice = value
                onToneProfileChanged(profile)
            }
            toneAxisPicker("Warmth", value: settings.defaultToneProfile.warmth) { value in
                var profile = settings.defaultToneProfile
                profile.warmth = value
                onToneProfileChanged(profile)
            }
            toneAxisPicker("Specificity", value: settings.defaultToneProfile.specificity) { value in
                var profile = settings.defaultToneProfile
                profile.specificity = value
                onToneProfileChanged(profile)
            }
            toneAxisPicker("Concision", value: settings.defaultToneProfile.concision) { value in
                var profile = settings.defaultToneProfile
                profile.concision = value
                onToneProfileChanged(profile)
            }
            toneAxisPicker("Evidence anchoring", value: settings.defaultToneProfile.evidenceAnchoring) { value in
                var profile = settings.defaultToneProfile
                profile.evidenceAnchoring = value
                onToneProfileChanged(profile)
            }
            Picker("Target length", selection: Binding(get: { settings.targetLength }, set: onTargetLengthChanged)) {
                ForEach(ReportLengthTarget.allCases, id: \.self) { target in
                    Text(targetLengthLabel(target)).tag(target)
                }
            }
            .disabled(isDisabled)
            .accessibilityIdentifier("ai-target-length-picker")
            WorklistFormRow(label: "Instruction") {
                TextField("Optional teacher instruction", text: Binding(get: { settings.customInstruction ?? "" }, set: onCustomInstructionChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("ai-custom-instruction-field")
            }
            WorklistFormRow(label: "Do not mention") {
                TextField("Comma, semicolon, or line separated details", text: Binding(
                    get: { mentionListText(settings.forbiddenMentions) },
                    set: { onForbiddenMentionsChanged(parseMentionList($0)) }
                ))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("ai-forbidden-mentions-field")
            }
            WorklistFormRow(label: "Required mentions") {
                TextField("Comma, semicolon, or line separated details", text: Binding(
                    get: { mentionListText(settings.requiredMentions) },
                    set: { onRequiredMentionsChanged(parseMentionList($0)) }
                ))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("ai-required-mentions-field")
            }
            Button(action: onResetBalanced) {
                WorklistActionRow(
                    title: "Reset Balanced Project Defaults",
                    subtitle: "Clears stored project AI defaults. Existing report text and draft-specific overrides are not changed.",
                    systemImage: "arrow.counterclockwise",
                    tone: .neutral,
                    isEnabled: hasStoredSettings && !isDisabled,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasStoredSettings || isDisabled)
            WorklistNote("Project defaults are stored in this local project and included in AI prompt metadata for drafts without overrides. Mention constraints are kept out of exports and enforced during validation.")
        }
    }

    private func toneAxisPicker(_ title: String, value: ToneAxis, onChange: @escaping (ToneAxis) -> Void) -> some View {
        tonePicker(title, selection: value, values: ToneAxis.allCases, label: toneAxisLabel, onChange: onChange)
    }

    private func tonePicker<Value: Hashable>(
        _ title: String,
        selection: Value,
        values: [Value],
        label: @escaping (Value) -> String,
        onChange: @escaping (Value) -> Void
    ) -> some View {
        Picker(title, selection: Binding(get: { selection }, set: onChange)) {
            ForEach(values, id: \.self) { value in
                Text(label(value)).tag(value)
            }
        }
        .disabled(isDisabled)
    }

    private func toneAxisLabel(_ axis: ToneAxis) -> String {
        switch axis {
        case .low:
            return "Low"
        case .slightlyLow:
            return "Slightly low"
        case .balanced:
            return "Balanced"
        case .slightlyHigh:
            return "Slightly high"
        case .high:
            return "High"
        }
    }

    private func schoolVoiceLabel(_ voice: SchoolVoice) -> String {
        switch voice {
        case .standard:
            return "Standard"
        case .warmPrimary:
            return "Warm primary"
        case .formalReport:
            return "Formal report"
        case .conciseSystem:
            return "Concise system"
        case .strengthsBased:
            return "Strengths based"
        }
    }

    private func targetLengthLabel(_ target: ReportLengthTarget) -> String {
        switch target {
        case .shorter:
            return "Shorter"
        case .standard:
            return "Standard"
        case .fuller:
            return "Fuller"
        case .strictCharacterLimit:
            return "Strict character limit"
        }
    }

    private func mentionListText(_ mentions: [String]) -> String {
        mentions.joined(separator: "; ")
    }

    private func parseMentionList(_ text: String) -> [String] {
        Array(
            Set(
                text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }
}

private struct AIReportOptionControls: View {
    let options: AIReportOptions
    let hasOverride: Bool
    let isDisabled: Bool
    let onToneProfileChanged: (AIToneProfile) -> Void
    let onTargetLengthChanged: (ReportLengthTarget) -> Void
    let onCustomInstructionChanged: (String) -> Void
    let onForbiddenMentionsChanged: ([String]) -> Void
    let onRequiredMentionsChanged: ([String]) -> Void
    let onSaveAsProjectDefaults: () -> Void
    let onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("This draft AI settings")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                Spacer(minLength: 0)
                WorklistStatusChip(hasOverride ? "Override" : "Project defaults", systemImage: hasOverride ? "slider.horizontal.3" : "arrow.triangle.2.circlepath", tone: hasOverride ? .prepared : .neutral)
            }
            reportToneAxisPicker("Warmth", value: options.toneProfile.warmth) { value in
                var profile = options.toneProfile
                profile.warmth = value
                onToneProfileChanged(profile)
            }
            reportToneAxisPicker("Specificity", value: options.toneProfile.specificity) { value in
                var profile = options.toneProfile
                profile.specificity = value
                onToneProfileChanged(profile)
            }
            reportToneAxisPicker("Next step directness", value: options.toneProfile.nextStepDirectness) { value in
                var profile = options.toneProfile
                profile.nextStepDirectness = value
                onToneProfileChanged(profile)
            }
            Picker("Target length", selection: Binding(get: { options.targetLength }, set: onTargetLengthChanged)) {
                ForEach(ReportLengthTarget.allCases, id: \.self) { target in
                    Text(targetLengthLabel(target)).tag(target)
                }
            }
            .disabled(isDisabled)
            .accessibilityIdentifier("report-ai-target-length-picker")
            WorklistFormRow(label: "Instruction") {
                TextField("Optional instruction for this draft", text: Binding(get: { options.customInstruction ?? "" }, set: onCustomInstructionChanged))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("report-ai-custom-instruction-field")
            }
            WorklistFormRow(label: "Do not mention") {
                TextField("Comma, semicolon, or line separated details", text: Binding(
                    get: { mentionListText(options.forbiddenMentions) },
                    set: { onForbiddenMentionsChanged(parseMentionList($0)) }
                ))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("report-ai-forbidden-mentions-field")
            }
            WorklistFormRow(label: "Required mentions") {
                TextField("Comma, semicolon, or line separated details", text: Binding(
                    get: { mentionListText(options.requiredMentions) },
                    set: { onRequiredMentionsChanged(parseMentionList($0)) }
                ))
                    .commenterWordsTextInput()
                    .disabled(isDisabled)
                    .accessibilityIdentifier("report-ai-required-mentions-field")
            }
            Button(action: onSaveAsProjectDefaults) {
                WorklistActionRow(
                    title: "Save as Project AI Defaults",
                    subtitle: "Copies this draft's AI settings into the local project defaults. Existing report text is not changed.",
                    systemImage: "square.and.arrow.down",
                    tone: .local,
                    isEnabled: hasOverride && !isDisabled,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasOverride || isDisabled)
            Button(action: onReset) {
                WorklistActionRow(
                    title: "Use Project AI Defaults",
                    subtitle: "Removes this draft's AI override. Existing report text is not changed.",
                    systemImage: "arrow.counterclockwise",
                    tone: .neutral,
                    isEnabled: hasOverride && !isDisabled,
                    showsChevron: false
                )
            }
            .buttonStyle(.plain)
            .disabled(!hasOverride || isDisabled)
            WorklistNote("These settings affect only new AI previews and validation for this draft. Mention constraints are kept out of exports. Do-not-mention details block approval if present; required mentions block approval if missing.")
        }
    }

    private func reportToneAxisPicker(_ title: String, value: ToneAxis, onChange: @escaping (ToneAxis) -> Void) -> some View {
        Picker(title, selection: Binding(get: { value }, set: onChange)) {
            ForEach(ToneAxis.allCases, id: \.self) { axis in
                Text(toneAxisLabel(axis)).tag(axis)
            }
        }
        .disabled(isDisabled)
    }

    private func toneAxisLabel(_ axis: ToneAxis) -> String {
        switch axis {
        case .low:
            return "Low"
        case .slightlyLow:
            return "Slightly low"
        case .balanced:
            return "Balanced"
        case .slightlyHigh:
            return "Slightly high"
        case .high:
            return "High"
        }
    }

    private func targetLengthLabel(_ target: ReportLengthTarget) -> String {
        switch target {
        case .shorter:
            return "Shorter"
        case .standard:
            return "Standard"
        case .fuller:
            return "Fuller"
        case .strictCharacterLimit:
            return "Strict character limit"
        }
    }

    private func mentionListText(_ mentions: [String]) -> String {
        mentions.joined(separator: "; ")
    }

    private func parseMentionList(_ text: String) -> [String] {
        Array(
            Set(
                text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        )
        .sorted()
    }
}

private struct AIRevisionPreviewCard: View {
    let pendingRevision: AppFeature.PendingAIRevision
    let isDisabled: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorklistStatusChip(statusTitle, systemImage: "doc.text.magnifyingglass", tone: pendingRevision.validation.status == .blocked ? .warning : .prepared)
            if !pendingRevision.changeSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WorklistNote(pendingRevision.changeSummary)
            }
            AIRevisionDiffView(original: pendingRevision.originalText, proposed: pendingRevision.proposedText)
            ReportValidationSummaryCard(title: "Preview validation", validation: pendingRevision.validation, notes: pendingRevision.reviewWarnings)
            HStack(spacing: 10) {
                Button(action: onReject) {
                    Label("Reject", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(CommenterStationeryTheme.Colors.attentionOrange)
                .disabled(isDisabled)
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(CommenterStationeryTheme.Colors.localGreen)
                .disabled(isDisabled || pendingRevision.validation.status == .blocked)
            }
        }
        .accessibilityIdentifier("ai-revision-preview-\(pendingRevision.studentId)-\(accessibilityKey(pendingRevision.subject))")
    }

    private var statusTitle: String {
        pendingRevision.validation.status == .blocked ? "AI preview needs fixes before acceptance" : "AI preview ready for teacher review"
    }
}

private struct AIRevisionDiffView: View {
    let original: String
    let proposed: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Before and after")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
            if removedSentences.isEmpty && addedSentences.isEmpty {
                WorklistNote("The revised text has no sentence-level additions or removals compared with the current draft.")
            } else {
                ForEach(removedSentences.prefix(3), id: \.self) { sentence in
                    diffRow(prefix: "Removed", text: sentence, tone: .warning)
                }
                ForEach(addedSentences.prefix(3), id: \.self) { sentence in
                    diffRow(prefix: "Added", text: sentence, tone: .local)
                }
            }
            DisclosureGroup("Proposed text") {
                Text(proposed)
                    .font(.body)
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
        }
    }

    private var removedSentences: [String] {
        sentenceSet(original).filter { !sentenceSet(proposed).contains($0) }
    }

    private var addedSentences: [String] {
        sentenceSet(proposed).filter { !sentenceSet(original).contains($0) }
    }

    private func diffRow(prefix: String, text: String, tone: WorklistTone) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(prefix)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone.color)
            Text(text)
                .font(.footnote)
                .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tone.softColor)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func sentenceSet(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private struct ReportValidationSummaryCard: View {
    let title: String
    let validation: ReportValidationSummary
    let notes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorklistStatusChip(statusTitle, systemImage: statusImage, tone: tone)
            ForEach(validation.findings.prefix(4)) { finding in
                VStack(alignment: .leading, spacing: 3) {
                    Text(finding.message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(finding.severity == .block ? CommenterStationeryTheme.Colors.destructiveRed : CommenterStationeryTheme.Colors.attentionOrange)
                        .fixedSize(horizontal: false, vertical: true)
                    if let suggestedFix = finding.suggestedFix {
                        Text(suggestedFix)
                            .font(.caption)
                            .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            ForEach(notes.prefix(3), id: \.self) { note in
                WorklistNote(note, tone: .neutral)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch validation.status {
        case .passed:
            return "\(title): passed"
        case .passedWithWarnings:
            return "\(title): \(validation.findings.count) warning \(validation.findings.count == 1 ? "item" : "items")"
        case .blocked:
            return "\(title): blocked"
        }
    }

    private var statusImage: String {
        switch validation.status {
        case .passed:
            return "checkmark.shield"
        case .passedWithWarnings:
            return "exclamationmark.triangle"
        case .blocked:
            return "xmark.shield"
        }
    }

    private var tone: WorklistTone {
        switch validation.status {
        case .passed:
            return .success
        case .passedWithWarnings:
            return .warning
        case .blocked:
            return .failure
        }
    }
}

private struct AIAvailabilityCard: View {
    let status: AppFeature.AIAvailabilityStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WorklistStatusChip(title, systemImage: systemImage, tone: tone)
            WorklistNote(detail, tone: tone == .warning || tone == .failure ? .warning : .neutral)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ai-availability-card")
    }

    private var title: String {
        switch status {
        case .notChecked:
            return "On-device AI not checked"
        case .checking:
            return "Checking on-device AI"
        case .checked(.available):
            return "On-device AI available"
        case .checked(.unavailable):
            return "On-device AI unavailable"
        case .failed:
            return "On-device AI check failed"
        }
    }

    private var detail: String {
        switch status {
        case .notChecked:
            return "Deterministic generation remains available. AI actions stay disabled until local availability is checked."
        case .checking:
            return "Checking local Apple Intelligence availability. No student data leaves the device."
        case .checked(.available):
            return "Apple on-device AI can be used only for teacher-reviewed drafts. Deterministic generation remains the fallback."
        case let .checked(.unavailable(reason)):
            return "AI actions are disabled because local availability reported \(reason.rawValue). Deterministic reports still work."
        case let .failed(message):
            return "AI actions are disabled because availability could not be checked: \(message)"
        }
    }

    private var systemImage: String {
        switch status {
        case .checked(.available):
            return "sparkles"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.triangle"
        case .notChecked, .checked(.unavailable):
            return "sparkles.rectangle.stack"
        }
    }

    private var tone: WorklistTone {
        switch status {
        case .checked(.available):
            return .local
        case .checking:
            return .prepared
        case .failed:
            return .failure
        case .notChecked, .checked(.unavailable):
            return .warning
        }
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
