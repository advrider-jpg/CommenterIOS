import CommentEngine
import CommenterDomain
import CommenterReportSafety
import ComposableArchitecture
extension AppFeature {
    func reduceProjectEditing(_ state: inout State, _ action: Action) -> Effect<Action> {
        guard !isAIWorkRunning(state) else {
            state.operationStatus = .failed("Wait for the current on-device AI request to finish, or cancel the bulk request, before editing the project.")
            return .none
        }
        switch action {
        case let .projectNameChanged(name):
            if updateSelectedProject(&state, mutate: { $0.metadata.name = name }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case let .projectTermChanged(term):
            if updateSelectedProject(&state, mutate: { $0.metadata.term = term }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case let .projectYearLevelChanged(yearLevel):
            if updateSelectedProject(&state, mutate: { $0.metadata.yearLevel = yearLevel }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case let .useFirstNameOnlyChanged(enabled):
            if updateSelectedProject(&state, mutate: { $0.metadata.useFirstNameOnly = enabled }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case .addStudentTapped:
            if updateSelectedProject(&state, mutate: { project in
                project.roster.append(
                    Student(
                        id: nextManualStudentId(in: project),
                        firstName: "",
                        lastName: "",
                        yearLevel: .year5
                    )
                )
            }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case let .deleteStudentTapped(studentId):
            if updateSelectedProject(&state, mutate: { project in
                project.roster.removeAll { $0.id == studentId }
                project.results.removeAll { $0.studentId == studentId }
                project.reports.removeAll { $0.studentId == studentId }
            }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentFirstNameChanged(studentId, value):
            if updateStudent(&state, id: studentId, mutate: { $0.firstName = value }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentLastNameChanged(studentId, value):
            if updateStudent(&state, id: studentId, mutate: { $0.lastName = value }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentYearLevelChanged(studentId, yearLevel):
            if updateStudent(&state, id: studentId, mutate: { $0.yearLevel = yearLevel }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentGenderChanged(studentId, gender):
            if updateStudent(&state, id: studentId, mutate: { $0.gender = gender }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentPronounsChanged(studentId, pronouns):
            if updateStudent(&state, id: studentId, mutate: { $0.pronouns = pronouns.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentInternalNoteChanged(studentId, note):
            if updateStudent(&state, id: studentId, mutate: { $0.internalTeacherNote = note.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .studentAttitudeDescriptorChanged(studentId, descriptor):
            if updateStudent(&state, id: studentId, mutate: { $0.attitudeDescriptor = descriptor.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId)
            }
            return .none

        case let .subjectToggled(subject):
            if updateSelectedProject(&state, mutate: { project in
                if project.metadata.selectedSubjects[subject] == nil {
                    project.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
                } else {
                    project.metadata.selectedSubjects.removeValue(forKey: subject)
                    project.results.removeAll { $0.subject == subject }
                    project.reports.removeAll { $0.subject == subject }
                }
            }) {
                invalidateAIReviewState(&state, subject: subject)
            }
            return .none

        case .subjectSelectAllTapped:
            if updateSelectedProject(&state, mutate: { project in
                teacherSubjectKeysInCurriculumOrder().forEach { subject in
                    project.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
                }
            }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case .subjectDeselectAllTapped:
            if updateSelectedProject(&state, mutate: { project in
                project.metadata.selectedSubjects.removeAll()
                project.results.removeAll()
                project.reports.removeAll()
            }) {
                invalidateAllAIReviewState(&state)
            }
            return .none

        case let .achievementLevelChanged(studentId, subject, level):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.achievementLevel = level }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .focusChanged(studentId, subject, focus):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.focusStrand = focus.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultEvidenceChanged(studentId, subject, evidence):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.evidenceText = evidence.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultTextTypeChanged(studentId, subject, textType):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.textType = textType.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultLearningContextChanged(studentId, subject, context):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.learningContext = context.nilIfBlank }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultReportEmphasisNoteChanged(studentId, subject, note):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: {
                $0.reportEmphasisNote = note.nilIfBlank
                $0.commentsText = nil
            }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultFlagChanged(studentId, subject, flagID, isEnabled):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { result in
                var flags = result.flags ?? [:]
                if isEnabled {
                    flags[flagID] = true
                } else {
                    flags.removeValue(forKey: flagID)
                }
                result.flags = flags.isEmpty ? nil : flags
            }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultEnglishFocusTagsChanged(studentId, subject, tags):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.englishFocusTags = tags.nilIfEmpty }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultMathProficienciesChanged(studentId, subject, proficiencies):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.mathProficiencies = proficiencies.nilIfEmpty }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultMathMindsetTogglesChanged(studentId, subject, toggles):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.mathMindsetToggles = toggles.nilIfEmpty }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .resultNextStepGoalsChanged(studentId, subject, goals):
            if updateResult(&state, studentId: studentId, subject: subject, mutate: { $0.nextStepGoals = goals.nilIfEmpty }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .reportManualEditChanged(studentId, subject, text):
            let projectBeforeEdit = state.selectedProject
            if updateReport(&state, studentId: studentId, subject: subject, mutate: { report in
                report.applyManualEdit(text)
                report.latestAIReviewNotes = nil
                report.validationWarningReview = nil
                markAIReportNeedsReviewIfRequired(&report, in: projectBeforeEdit, nowMilliseconds: dateClient.nowMilliseconds())
            }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .reportLockChanged(studentId, subject, isLocked):
            if updateReport(&state, studentId: studentId, subject: subject, mutate: { $0.isLocked = isLocked }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
            }
            return .none

        case let .reportMarkedDone(studentId, subject):
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before marking a draft Done.")
                return .none
            }
            let readiness = getReportReadiness(project: project, studentId: studentId, subject: subject)
            guard readiness.status == .needsTeacherCheck else {
                if isReadyForExport(readiness.status) {
                    state.operationStatus = .saved("This draft is already marked Done and is included in export.")
                } else {
                    state.operationStatus = .failed("This draft cannot be marked Done yet. \(readiness.message)")
                }
                return .none
            }
            let reviewedAt = dateClient.nowMilliseconds()
            if updateReport(&state, studentId: studentId, subject: subject, mutate: { report in
                report.markTeacherReviewed(at: reviewedAt)
            }) {
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
                state.operationStatus = .dirty("Draft marked Done. Save the project to persist its teacher-review status and include it in export.")
            }
            return .none

        case let .reportApprovedForExport(studentId, subject):
            let hasWaitingPreview = (state.pendingAIRevision?.studentId == studentId && state.pendingAIRevision?.subject == subject)
                || state.pendingAIRevisions.contains { $0.studentId == studentId && $0.subject == subject }
            guard !hasWaitingPreview else {
                state.operationStatus = .failed("Accept or reject the waiting AI preview before approving this draft for export.")
                return .none
            }
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
                invalidateAIReviewState(&state, studentID: studentId, subject: subject)
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
            invalidateAIReviewState(&state, studentID: studentId, subject: subject)
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
