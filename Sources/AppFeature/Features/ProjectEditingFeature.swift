import CommentEngine
import CommenterDomain
import CommenterReportSafety
import ComposableArchitecture
extension AppFeature {
    func reduceProjectEditing(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .projectNameChanged(name):
            updateSelectedProject(&state) { $0.metadata.name = name }
            return .none

        case let .projectTermChanged(term):
            updateSelectedProject(&state) { $0.metadata.term = term }
            return .none

        case let .projectYearLevelChanged(yearLevel):
            updateSelectedProject(&state) { $0.metadata.yearLevel = yearLevel }
            return .none

        case let .useFirstNameOnlyChanged(enabled):
            updateSelectedProject(&state) { $0.metadata.useFirstNameOnly = enabled }
            return .none

        case .addStudentTapped:
            updateSelectedProject(&state) { project in
                project.roster.append(
                    Student(
                        id: nextManualStudentId(in: project),
                        firstName: "",
                        lastName: "",
                        yearLevel: .year5
                    )
                )
            }
            return .none

        case let .deleteStudentTapped(studentId):
            updateSelectedProject(&state) { project in
                project.roster.removeAll { $0.id == studentId }
                project.results.removeAll { $0.studentId == studentId }
                project.reports.removeAll { $0.studentId == studentId }
            }
            return .none

        case let .studentFirstNameChanged(studentId, value):
            updateStudent(&state, id: studentId) { $0.firstName = value }
            return .none

        case let .studentLastNameChanged(studentId, value):
            updateStudent(&state, id: studentId) { $0.lastName = value }
            return .none

        case let .studentYearLevelChanged(studentId, yearLevel):
            updateStudent(&state, id: studentId) { $0.yearLevel = yearLevel }
            return .none

        case let .studentGenderChanged(studentId, gender):
            updateStudent(&state, id: studentId) { $0.gender = gender }
            return .none

        case let .studentPronounsChanged(studentId, pronouns):
            updateStudent(&state, id: studentId) { $0.pronouns = pronouns.nilIfBlank }
            return .none

        case let .studentInternalNoteChanged(studentId, note):
            updateStudent(&state, id: studentId) { $0.internalTeacherNote = note.nilIfBlank }
            return .none

        case let .studentAttitudeDescriptorChanged(studentId, descriptor):
            updateStudent(&state, id: studentId) { $0.attitudeDescriptor = descriptor.nilIfBlank }
            return .none

        case let .subjectToggled(subject):
            updateSelectedProject(&state) { project in
                if project.metadata.selectedSubjects[subject] == nil {
                    project.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
                } else {
                    project.metadata.selectedSubjects.removeValue(forKey: subject)
                    project.results.removeAll { $0.subject == subject }
                    project.reports.removeAll { $0.subject == subject }
                }
            }
            return .none

        case .subjectSelectAllTapped:
            updateSelectedProject(&state) { project in
                teacherSubjectKeysInCurriculumOrder().forEach { subject in
                    project.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
                }
            }
            return .none

        case .subjectDeselectAllTapped:
            updateSelectedProject(&state) { project in
                project.metadata.selectedSubjects.removeAll()
                project.results.removeAll()
                project.reports.removeAll()
            }
            return .none

        case let .achievementLevelChanged(studentId, subject, level):
            updateResult(&state, studentId: studentId, subject: subject) { $0.achievementLevel = level }
            return .none

        case let .focusChanged(studentId, subject, focus):
            updateResult(&state, studentId: studentId, subject: subject) { $0.focusStrand = focus.nilIfBlank }
            return .none

        case let .resultEvidenceChanged(studentId, subject, evidence):
            updateResult(&state, studentId: studentId, subject: subject) { $0.evidenceText = evidence.nilIfBlank }
            return .none

        case let .resultTextTypeChanged(studentId, subject, textType):
            updateResult(&state, studentId: studentId, subject: subject) { $0.textType = textType.nilIfBlank }
            return .none

        case let .resultLearningContextChanged(studentId, subject, context):
            updateResult(&state, studentId: studentId, subject: subject) { $0.learningContext = context.nilIfBlank }
            return .none

        case let .resultReportEmphasisNoteChanged(studentId, subject, note):
            updateResult(&state, studentId: studentId, subject: subject) {
                $0.reportEmphasisNote = note.nilIfBlank
                $0.commentsText = nil
            }
            return .none

        case let .resultFlagChanged(studentId, subject, flagID, isEnabled):
            updateResult(&state, studentId: studentId, subject: subject) { result in
                var flags = result.flags ?? [:]
                if isEnabled {
                    flags[flagID] = true
                } else {
                    flags.removeValue(forKey: flagID)
                }
                result.flags = flags.isEmpty ? nil : flags
            }
            return .none

        case let .resultEnglishFocusTagsChanged(studentId, subject, tags):
            updateResult(&state, studentId: studentId, subject: subject) { $0.englishFocusTags = tags.nilIfEmpty }
            return .none

        case let .resultMathProficienciesChanged(studentId, subject, proficiencies):
            updateResult(&state, studentId: studentId, subject: subject) { $0.mathProficiencies = proficiencies.nilIfEmpty }
            return .none

        case let .resultMathMindsetTogglesChanged(studentId, subject, toggles):
            updateResult(&state, studentId: studentId, subject: subject) { $0.mathMindsetToggles = toggles.nilIfEmpty }
            return .none

        case let .resultNextStepGoalsChanged(studentId, subject, goals):
            updateResult(&state, studentId: studentId, subject: subject) { $0.nextStepGoals = goals.nilIfEmpty }
            return .none

        case let .reportManualEditChanged(studentId, subject, text):
            let projectBeforeEdit = state.selectedProject
            updateReport(&state, studentId: studentId, subject: subject) { report in
                report.manualEdit = text
                report.latestAIReviewNotes = nil
                report.validationWarningReview = nil
                markAIReportNeedsReviewIfRequired(&report, in: projectBeforeEdit, nowMilliseconds: dateClient.nowMilliseconds())
            }
            return .none

        case let .reportLockChanged(studentId, subject, isLocked):
            updateReport(&state, studentId: studentId, subject: subject) { $0.isLocked = isLocked }
            return .none

        case let .reportApprovedForExport(studentId, subject):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open an AI draft before approving it for export.")
                return .none
            }
            guard report.requiresTeacherApprovalForExport else {
                state.operationStatus = .failed("This deterministic draft does not require AI review approval.")
                return .none
            }
            let validation = validateReportForAIReview(project: project, report: report, nowMilliseconds: dateClient.nowMilliseconds())
            guard validation.status != .blocked else {
                updateReport(&state, studentId: studentId, subject: subject) { report in
                    let currentFingerprint = stableTextFingerprint(report.exportText)
                    report.currentTextFingerprint = currentFingerprint
                    report.lastValidation = validation
                    report.validationWarningReview = nil
                    report.reviewState = ReportReviewState(
                        status: .blockedByValidation,
                        reviewedAt: dateClient.nowMilliseconds(),
                        notes: validation.findings.map(\.message).joined(separator: " ")
                    )
                }
                state.operationStatus = .failed("AI draft cannot be approved until validation blockers are fixed.")
                return .none
            }
            updateReport(&state, studentId: studentId, subject: subject) { report in
                let reviewedAt = dateClient.nowMilliseconds()
                let currentFingerprint = stableTextFingerprint(report.exportText)
                report.currentTextFingerprint = currentFingerprint
                report.approvedTextFingerprint = currentFingerprint
                report.lastValidation = validation
                report.validationWarningReview = validation.status == .passedWithWarnings
                    ? ReportWarningReviewRecord(
                        validationFingerprint: currentFingerprint,
                        reviewedAt: reviewedAt,
                        reviewerDisplayName: "Local teacher",
                        notes: validation.findings.map(\.message).joined(separator: " ")
                    )
                    : nil
                report.reviewState = ReportReviewState(
                    status: .approved,
                    reviewedAt: reviewedAt,
                    approvedAt: reviewedAt,
                    reviewerDisplayName: "Local teacher",
                    approvalFingerprint: currentFingerprint
                )
            }
            return .none

        default:
            return .none
        }
    }
}

private func markAIReportNeedsReviewIfRequired(_ report: inout GeneratedReport, in project: Project?, nowMilliseconds: Int64) {
    guard report.requiresTeacherApprovalForExport else { return }
    report.generationMode = report.effectiveGenerationMode == .manuallyEdited ? .manuallyEdited : .hybrid
    report.currentTextFingerprint = stableTextFingerprint(report.exportText)
    if let project {
        report.lastValidation = validateReportForAIReview(project: project, report: report, nowMilliseconds: nowMilliseconds)
    }
    report.latestAIReviewNotes = nil
    report.validationWarningReview = nil
    report.reviewState = ReportReviewState(status: .needsTeacherReview, reviewedAt: nil, approvedAt: nil, approvalFingerprint: nil)
    report.approvedTextFingerprint = nil
}

private func nextManualStudentId(in project: Project) -> String {
    let existingIds = Set(project.roster.map(\.id))
    var counter = project.roster.count + 1
    while existingIds.contains("student-\(counter)") {
        counter += 1
    }
    return "student-\(counter)"
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : self
    }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? {
        let values = map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values
    }
}
