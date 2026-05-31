import CommentEngine
import CommenterDomain

private let supportedSubjects = [
    "English",
    "Mathematics",
    "Science",
    "HASS",
    "Health and P.E.",
    "The Arts",
    "Technologies"
]

public func availableTeacherSubjects() -> [String] {
    supportedSubjects
}

func updateSelectedProject(_ state: inout AppFeature.State, mutate: (inout Project) -> Void) {
    guard var project = state.selectedProject else { return }
    mutate(&project)
    state.selectedProject = project
    state.selectedProjectReadiness = getProjectReadiness(project)
    state.pendingImport = nil
    state.operationStatus = .dirty("Unsaved changes. Save to persist them on this device.")
}

func updateStudent(_ state: inout AppFeature.State, id: String, mutate: (inout Student) -> Void) {
    updateSelectedProject(&state) { project in
        guard let index = project.roster.firstIndex(where: { $0.id == id }) else { return }
        mutate(&project.roster[index])
    }
}

func updateResult(
    _ state: inout AppFeature.State,
    studentId: String,
    subject: String,
    mutate: (inout AchievementResult) -> Void
) {
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

func updateReport(
    _ state: inout AppFeature.State,
    studentId: String,
    subject: String,
    mutate: (inout GeneratedReport) -> Void
) {
    updateSelectedProject(&state) { project in
        guard let index = project.reports.firstIndex(where: { $0.studentId == studentId && $0.subject == subject }) else { return }
        mutate(&project.reports[index])
    }
}

func acceptVerifiedProject(_ state: inout AppFeature.State, project: Project, message: String) {
    state.projectStorageStatus = .loaded
    state.selectedProject = project
    state.selectedProjectReadiness = getProjectReadiness(project)
    state.pendingImport = nil
    state.preparedFile = nil
    state.operationStatus = .saved(message)
    state.workflowMessage = message
    state.projects.removeAll { $0.id == project.metadata.id }
    state.projects.append(projectSummary(project))
    state.projects = sortedProjects(state.projects)
}

func sortedProjects(_ projects: [ProjectSummary]) -> [ProjectSummary] {
    projects.sorted { $0.updatedAt > $1.updatedAt }
}

func projectStorageLoadedMessage(projectCount: Int) -> String {
    if projectCount == 0 {
        return "Project storage is available. No saved projects were found on this device."
    }
    let label = projectCount == 1 ? "project" : "projects"
    return "\(projectCount) saved \(label) loaded from local storage."
}

func generationSuccessMessage(_ result: CommentGenerationResult) -> String {
    let generatedLabel = result.generatedCount == 1 ? "1 report" : "\(result.generatedCount) reports"
    guard result.skippedLockedCount > 0 else {
        return "\(generatedLabel) generated, saved, and verified."
    }
    let lockedLabel = result.skippedLockedCount == 1 ? "1 locked report" : "\(result.skippedLockedCount) locked reports"
    return "\(generatedLabel) generated, \(lockedLabel) left unchanged, saved, and verified."
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
