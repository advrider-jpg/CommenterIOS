import CommenterDomain
import Foundation

public enum ProjectImportCommitError: LocalizedError, Equatable {
    case emptyRosterImport
    case emptyResultsImport
    case invalidExistingProject([String])
    case invalidImportedProject([String])

    public var errorDescription: String? {
        switch self {
        case .emptyRosterImport:
            return "No students were prepared for import. Existing project data was left unchanged."
        case .emptyResultsImport:
            return "No results were prepared for import. Existing project data was left unchanged."
        case let .invalidExistingProject(issues):
            return "The existing project is not valid enough to import into: \(issues.joined(separator: " "))"
        case let .invalidImportedProject(issues):
            return "Import blocked. Existing project data was left unchanged: \(issues.joined(separator: " "))"
        }
    }
}

public enum ProjectImportChangeKind: Equatable, Sendable {
    case roster
    case results
}

public struct PreparedProjectImportChange: Equatable, Sendable {
    public var kind: ProjectImportChangeKind
    public var importedCount: Int
    public var project: Project

    public init(kind: ProjectImportChangeKind, importedCount: Int, project: Project) {
        self.kind = kind
        self.importedCount = importedCount
        self.project = project
    }
}

public func projectByApplyingRosterImport(
    _ importedStudents: [Student],
    to project: Project,
    nowMilliseconds: Int64
) throws -> PreparedProjectImportChange {
    guard !importedStudents.isEmpty else {
        throw ProjectImportCommitError.emptyRosterImport
    }
    try validateImportBaseProject(project)

    var next = project
    next.metadata.updatedAt = nowMilliseconds
    next.roster.append(contentsOf: importedStudents)

    try validatePreparedImportProject(next)
    return PreparedProjectImportChange(kind: .roster, importedCount: importedStudents.count, project: next)
}

public func projectByApplyingResultsImport(
    _ importedResults: [AchievementResult],
    to project: Project,
    nowMilliseconds: Int64
) throws -> PreparedProjectImportChange {
    guard !importedResults.isEmpty else {
        throw ProjectImportCommitError.emptyResultsImport
    }
    try validateImportBaseProject(project)

    var mergedResults = project.results
    importedResults.forEach { importedResult in
        if let index = mergedResults.firstIndex(where: { $0.studentId == importedResult.studentId && $0.subject == importedResult.subject }) {
            mergedResults[index] = importedResult
        } else {
            mergedResults.append(importedResult)
        }
    }

    var next = project
    next.metadata.updatedAt = nowMilliseconds
    next.results = mergedResults

    try validatePreparedImportProject(next)
    return PreparedProjectImportChange(kind: .results, importedCount: importedResults.count, project: next)
}

private func validateImportBaseProject(_ project: Project) throws {
    let validation = validateStoredProjectShape(project)
    guard validation.ok else {
        throw ProjectImportCommitError.invalidExistingProject(validation.issues)
    }
}

private func validatePreparedImportProject(_ project: Project) throws {
    let validation = validateStoredProjectShape(project)
    guard validation.ok else {
        throw ProjectImportCommitError.invalidImportedProject(validation.issues)
    }
}
