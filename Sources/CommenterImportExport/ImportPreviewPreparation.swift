import CommenterDomain
import Foundation

public struct PreparedProjectImportPreview: Equatable, Sendable {
    public var sourceFormat: ImportExportFormat
    public var change: PreparedProjectImportChange

    public init(sourceFormat: ImportExportFormat, change: PreparedProjectImportChange) {
        self.sourceFormat = sourceFormat
        self.change = change
    }

    public var acceptedRows: Int {
        change.importedCount
    }
}

public enum ImportPreviewPreparationError: LocalizedError, Equatable {
    case noAcceptedRows(String)

    public var errorDescription: String? {
        switch self {
        case let .noAcceptedRows(rowLabel):
            return "No \(rowLabel) rows were accepted for import. Existing project data was left unchanged."
        }
    }
}

public func prepareRosterImportPreview(
    from url: URL,
    project: Project,
    nowMilliseconds: Int64,
    createID: () throws -> String
) throws -> PreparedProjectImportPreview {
    let (format, parsed) = try parseTabularImportPreviewFile(
        from: url,
        importLabel: "Roster",
        acceptedRowLabel: "student"
    )
    let students = try ImportValidation.parseRosterImportRows(
        parsed,
        existingRoster: project.roster,
        createID: createID
    )
    guard !students.isEmpty else {
        throw ImportPreviewPreparationError.noAcceptedRows("student")
    }
    let change: PreparedProjectImportChange
    do {
        change = try projectByApplyingRosterImport(
            students,
            to: project,
            nowMilliseconds: nowMilliseconds
        )
    } catch let error as ProjectImportCommitError where error == .emptyRosterImport {
        throw ImportPreviewPreparationError.noAcceptedRows("student")
    }
    return try validatedProjectImportPreview(sourceFormat: format, change: change, acceptedRowLabel: "student")
}

public func prepareResultsImportPreview(
    from url: URL,
    project: Project,
    nowMilliseconds: Int64
) throws -> PreparedProjectImportPreview {
    let (format, parsed) = try parseTabularImportPreviewFile(
        from: url,
        importLabel: "Results",
        acceptedRowLabel: "result"
    )
    let results = try ImportValidation.parseResultsImportRows(
        parsed,
        roster: project.roster,
        selectedSubjects: project.metadata.selectedSubjects
    )
    guard !results.isEmpty else {
        throw ImportPreviewPreparationError.noAcceptedRows("result")
    }
    let change: PreparedProjectImportChange
    do {
        change = try projectByApplyingResultsImport(
            results,
            to: project,
            nowMilliseconds: nowMilliseconds
        )
    } catch let error as ProjectImportCommitError where error == .emptyResultsImport {
        throw ImportPreviewPreparationError.noAcceptedRows("result")
    }
    return try validatedProjectImportPreview(sourceFormat: format, change: change, acceptedRowLabel: "result")
}

private func parseTabularImportPreviewFile(
    from url: URL,
    importLabel: String,
    acceptedRowLabel: String
) throws -> (ImportExportFormat, CSVParseResult) {
    let format = try SpreadsheetImportFile.importFormat(for: url, label: importLabel)
    do {
        let parsed = try SpreadsheetImportFile.parseTabularImportFile(url: url, label: importLabel)
        return (format, parsed)
    } catch CSVParserError.missingDataRows(_) {
        throw ImportPreviewPreparationError.noAcceptedRows(acceptedRowLabel)
    }
}

private func validatedProjectImportPreview(
    sourceFormat: ImportExportFormat,
    change: PreparedProjectImportChange,
    acceptedRowLabel: String
) throws -> PreparedProjectImportPreview {
    guard change.importedCount > 0 else {
        throw ImportPreviewPreparationError.noAcceptedRows(acceptedRowLabel)
    }
    return PreparedProjectImportPreview(sourceFormat: sourceFormat, change: change)
}
