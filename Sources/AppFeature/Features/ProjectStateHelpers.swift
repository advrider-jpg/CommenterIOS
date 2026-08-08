import CommentEngine
import CommenterDomain
import CommenterImportExport
import CommenterReportSafety
import Foundation

public func availableTeacherSubjects() -> [String] {
    teacherSubjectKeysInCurriculumOrder()
}

@discardableResult
func updateSelectedProject(_ state: inout AppFeature.State, mutate: (inout Project) -> Void) -> Bool {
    guard var project = state.selectedProject else { return false }
    let originalProject = project
    mutate(&project)
    guard project != originalProject else { return false }
    state.selectedProject = project
    state.selectedProjectReadiness = getProjectReadiness(project)
    state.pendingImport = nil
    markPreparedFileStale(&state)
    markImportStatesStaleAfterManualEdit(&state)
    state.hasUnsavedProjectChanges = true
    state.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
    return true
}

@discardableResult
func updateStudent(_ state: inout AppFeature.State, id: String, mutate: (inout Student) -> Void) -> Bool {
    updateSelectedProject(&state) { project in
        guard let index = project.roster.firstIndex(where: { $0.id == id }) else { return }
        mutate(&project.roster[index])
    }
}

@discardableResult
func updateResult(
    _ state: inout AppFeature.State,
    studentId: String,
    subject: String,
    mutate: (inout AchievementResult) -> Void
) -> Bool {
    updateSelectedProject(&state) { project in
        if let index = project.results.firstIndex(where: { $0.studentId == studentId && $0.subject == subject }) {
            mutate(&project.results[index])
        } else {
            var result = AchievementResult(studentId: studentId, subject: subject)
            mutate(&result)
            project.results.append(result)
        }
    }
}

@discardableResult
func updateReport(
    _ state: inout AppFeature.State,
    studentId: String,
    subject: String,
    mutate: (inout GeneratedReport) -> Void
) -> Bool {
    updateSelectedProject(&state) { project in
        guard let index = project.reports.firstIndex(where: { $0.studentId == studentId && $0.subject == subject }) else { return }
        mutate(&project.reports[index])
    }
}

func acceptVerifiedProject(_ state: inout AppFeature.State, project: Project, message: String) {
    if state.preparedFile?.projectID != project.metadata.id || hasUnsavedChanges(state) {
        markPreparedFileStale(&state)
    }
    state.projectStorageStatus = .loaded
    state.selectedProject = project
    state.selectedProjectReadiness = getProjectReadiness(project)
    state.pendingImport = nil
    state.hasUnsavedProjectChanges = false
    state.operationStatus = .saved(message)
    state.workflowMessage = message
    state.projects.removeAll { $0.id == project.metadata.id }
    state.projects.append(projectSummary(project))
    state.projects = sortedProjects(state.projects)
}

func markPreparedFileStale(_ state: inout AppFeature.State) {
    guard state.preparedFile?.purpose == .projectOutput else { return }
    state.preparedFile?.isStale = true
}

func invalidateAIReviewState(
    _ state: inout AppFeature.State,
    studentID: String? = nil,
    subject: String? = nil
) {
    func matches(_ candidateStudentID: String, _ candidateSubject: String) -> Bool {
        (studentID == nil || studentID == candidateStudentID)
            && (subject == nil || subject == candidateSubject)
    }

    if let pending = state.pendingAIRevision, matches(pending.studentId, pending.subject) {
        state.pendingAIRevision = nil
    }
    state.pendingAIRevisions.removeAll { matches($0.studentId, $0.subject) }
    if let latest = state.latestReportCheck, matches(latest.studentId, latest.subject) {
        state.latestReportCheck = nil
    }
}

func invalidateAllAIReviewState(_ state: inout AppFeature.State) {
    state.pendingAIRevision = nil
    state.pendingAIRevisions = []
    state.latestReportCheck = nil
}

func isAIWorkRunning(_ state: AppFeature.State) -> Bool {
    state.activeAIRequest != nil || state.isBulkAIRevisionRunning
}

func sortedProjects(_ projects: [ProjectSummary]) -> [ProjectSummary] {
    projects.sorted { $0.updatedAt > $1.updatedAt }
}

func projectStorageLoadedMessage(projectCount: Int, invalidProjectCount: Int = 0) -> String {
    let invalidSuffix: String
    if invalidProjectCount == 0 {
        invalidSuffix = ""
    } else {
        let invalidLabel = invalidProjectCount == 1 ? "record" : "records"
        invalidSuffix = " \(invalidProjectCount) local project \(invalidLabel) could not be loaded and is listed in Support diagnostics."
    }

    if projectCount == 0 {
        return "Project storage is available and ready." + invalidSuffix
    }
    let label = projectCount == 1 ? "project" : "projects"
    return "\(projectCount) saved \(label) loaded from local storage." + invalidSuffix
}

func generationSuccessMessage(_ result: CommentGenerationResult) -> String {
    let generatedLabel = result.generatedCount == 1 ? "1 draft comment" : "\(result.generatedCount) draft comments"
    guard result.skippedLockedCount > 0 else {
        return "\(generatedLabel) generated deterministically, saved, and verified. Read each new draft and mark it Done before export."
    }
    let lockedLabel = result.skippedLockedCount == 1 ? "1 locked draft" : "\(result.skippedLockedCount) locked drafts"
    return "\(generatedLabel) generated deterministically, \(lockedLabel) left unchanged, saved, and verified. Read each new draft and mark it Done before export."
}

func projectSummary(_ project: Project) -> ProjectSummary {
    ProjectSummary(
        id: project.metadata.id,
        name: project.metadata.name,
        term: project.metadata.term,
        updatedAt: project.metadata.updatedAt,
        revision: project.metadata.persistence?.revision
    )
}

func isLongRunningProjectOperation(_ status: AppFeature.ProjectStorageStatus) -> Bool {
    switch status {
    case .creating, .loadingProject, .saving, .deleting, .preparingFile, .importing, .generating:
        return true
    case .notLoaded, .loading, .loaded, .failed:
        return false
    }
}

func hasUnsavedChanges(_ state: AppFeature.State) -> Bool {
    if state.hasUnsavedProjectChanges {
        return true
    }
    if case .dirty = state.operationStatus {
        return true
    }
    return false
}

func importSourceLabel(_ format: ImportExportFormat?) -> String {
    format?.rawValue.uppercased() ?? "file"
}

func markImportStatesStaleAfterManualEdit(_ state: inout AppFeature.State) {
    if case .success = state.rosterImportState {
        state.rosterImportState = .stale("Roster was edited after the last import. Save the project to verify the current roster.")
    } else if case .loaded = state.rosterImportState {
        state.rosterImportState = .stale("Roster changed after the project was opened. Save the project to verify the current roster.")
    }
    if case .success = state.resultsImportState {
        state.resultsImportState = .stale("Project data changed after the last results import. Review results before regenerating draft comments.")
    } else if case .loaded = state.resultsImportState {
        state.resultsImportState = .stale("Project data changed after the project was opened. Review results before regenerating draft comments.")
    }
}

func generationPrerequisiteMessages(project: Project?, datasetStatus: AppFeature.DatasetStatus) -> [String] {
    guard let project else {
        return ["Open a project."]
    }
    var messages: [String] = []
    if project.roster.isEmpty {
        messages.append("Add at least one student.")
    }
    if selectedSubjectKeys(project.metadata.selectedSubjects).isEmpty {
        messages.append("Select at least one subject.")
    }
    let resultReadiness = getExpectedReportKeys(project: project).map {
        getResultReadiness(project: project, studentId: $0.student.id, subject: $0.subject)
    }
    if !resultReadiness.isEmpty {
        let blockedResults = resultReadiness.filter { $0.status != .ready }
        if !blockedResults.isEmpty {
            messages.append("Complete achievement results for \(blockedResults.count) student-subject \(blockedResults.count == 1 ? "entry" : "entries").")
        }
    }
    if case .loaded = datasetStatus {
    } else {
        messages.append("Wait for the bundled production dataset to load.")
    }
    return messages
}

func reportGenerationButtonTitle(project: Project, readiness: ProjectReadiness?) -> String {
    guard let readiness, readiness.expected > 0 else {
        return "Generate Draft Comments"
    }
    if readiness.entries.contains(where: { $0.status == .staleReport || $0.status == .lockedStale }) {
        return "Regenerate Draft Comments"
    }
    if readiness.expected > 0, readiness.ready == readiness.expected {
        return "Draft Comments Up to Date"
    }
    if project.reports.isEmpty {
        return "Generate Draft Comments"
    }
    return "Review Draft Comments"
}

func reportGenerationDisabledReason(project: Project, readiness: ProjectReadiness?, datasetStatus: AppFeature.DatasetStatus? = nil) -> String? {
    let prerequisiteMessages = generationPrerequisiteMessages(project: project, datasetStatus: datasetStatus ?? .loaded(DatasetSnapshot(hash: "", normalizedSourceHash: "", subjectCount: 0, componentCount: 0, recipeCount: 0, assembledVariantCount: 0, uniquenessGuardCount: 0, warnings: [], summary: "")))
    let relevant = prerequisiteMessages.filter { !$0.contains("dataset") && !$0.contains("Open") }
    if !relevant.isEmpty {
        return relevant.joined(separator: " ")
    }
    guard let readiness else {
        return "Results must be reviewed before draft comments can be generated."
    }
    if readiness.expected == 0 {
        return "Add students, select subjects, and enter results before generating draft comments."
    }
    let resultBlocked = readiness.entries.filter { entry in
        entry.status == .missingAchievementLevel || entry.status == .missingConcreteFocus
    }
    if !resultBlocked.isEmpty {
        return "Complete results for \(resultBlocked.count) student-subject \(resultBlocked.count == 1 ? "entry" : "entries") before generating."
    }
    if readiness.ready == readiness.expected {
        return "All draft comments are up to date and export-ready."
    }
    return nil
}

func validateReportForAIReview(project: Project, report: GeneratedReport, nowMilliseconds: Int64) -> ReportValidationSummary {
    guard let context = reportValidationContextForAIReview(project: project, report: report, nowMilliseconds: nowMilliseconds) else {
        return ReportValidationSummary(
            status: .blocked,
            findings: [
                ReportValidationFinding(
                    id: "missing-student",
                    severity: .block,
                    category: .name,
                    message: "The report references a student that is no longer in the project."
                )
            ],
            validatedAt: nowMilliseconds,
            textFingerprint: stableTextFingerprint(report.exportText)
        )
    }
    return ReportSafetyValidator.validate(text: report.exportText, context: context)
}

func reportValidationContextForAIReview(project: Project, report: GeneratedReport, nowMilliseconds: Int64) -> ReportValidationContext? {
    guard let student = project.roster.first(where: { $0.id == report.studentId }) else {
        return nil
    }
    let result = project.results.first { $0.studentId == report.studentId && $0.subject == report.subject }
    let allowedFacts = reportSafeFacts(project: project, result: result, report: report)
    let options = effectiveAIOptions(project: project, report: report)
    return ReportValidationContext(
        student: student,
        projectMetadata: project.metadata,
        subject: report.subject,
        allowedFacts: allowedFacts,
        deterministicDraft: report.text,
        knownStudents: project.roster,
        achievementLevel: result?.achievementLevel,
        forbiddenMentions: options.forbiddenMentions,
        requiredMentions: options.requiredMentions,
        validatedAt: nowMilliseconds
    )
}

func effectiveAIOptions(project: Project, report: GeneratedReport) -> AIReportOptions {
    report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
}

func reportSafeFacts(project: Project, result: AchievementResult?, report: GeneratedReport) -> [ReportSafeFact] {
    var facts: [ReportSafeFact] = [
        ReportSafeFact(id: "draft-\(stableTextFingerprint(report.text))", text: report.text, source: .deterministicDraft)
    ]
    if let evidence = result?.evidenceText?.trimmingCharacters(in: .whitespacesAndNewlines), !evidence.isEmpty {
        facts.append(ReportSafeFact(id: "evidence-\(stableTextFingerprint(evidence))", text: evidence, source: .achievementResultEvidence))
    }
    if let context = result?.learningContext?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty {
        facts.append(ReportSafeFact(id: "context-\(stableTextFingerprint(context))", text: context, source: .learningContext))
    }
    if let note = result?.reportEmphasisNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
        facts.append(ReportSafeFact(id: "note-\(stableTextFingerprint(note))", text: note, source: .reportEmphasisNote))
    }
    return facts
}
