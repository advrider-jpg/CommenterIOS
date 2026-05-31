import CommentEngine
import CommenterDomain
import CommenterImportExport
import ComposableArchitecture
import Foundation

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .projects
        public var datasetStatus: DatasetStatus = .notLoaded
        public var projectStorageStatus: ProjectStorageStatus = .notLoaded
        public var projects: [ProjectSummary] = []
        public var selectedProject: Project?
        public var selectedProjectReadiness: ProjectReadiness?
        public var projectStorageMessage = "Checking local project storage."
        public var workflowMessage = "Open or create a project to manage roster, subjects, results, drafts, backups, and exports."
        public var operationStatus: OperationStatus = .idle
        public var preparedFile: PreparedFile?
        public var pendingImport: PendingImport?

        public init() {}
    }

    public enum Tab: String, CaseIterable, Equatable, Sendable {
        case projects
        case worklist
        case support
    }

    public enum DatasetStatus: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded(DatasetSnapshot)
        case failed(String)
    }

    public enum ProjectStorageStatus: Equatable, Sendable {
        case notLoaded
        case loading
        case loaded
        case creating
        case loadingProject
        case saving
        case preparingFile
        case importing
        case generating
        case failed(String)
    }

    public enum OperationStatus: Equatable, Sendable {
        case idle
        case dirty(String)
        case busy(String)
        case saved(String)
        case prepared(String)
        case cancelled(String)
        case failed(String)
    }

    public struct PreparedFile: Equatable, Sendable {
        public var url: URL
        public var label: String

        public init(url: URL, label: String) {
            self.url = url
            self.label = label
        }
    }

    public struct PendingImport: Equatable, Sendable {
        public var project: Project
        public var title: String
        public var detail: String
        public var successMessage: String
        public var expectedRevision: Int?
        public var recoveryReason: RecoveryReason

        public init(
            project: Project,
            title: String,
            detail: String,
            successMessage: String,
            expectedRevision: Int?,
            recoveryReason: RecoveryReason
        ) {
            self.project = project
            self.title = title
            self.detail = detail
            self.successMessage = successMessage
            self.expectedRevision = expectedRevision
            self.recoveryReason = recoveryReason
        }
    }

    public enum Action: Equatable, Sendable {
        case task
        case tabSelected(Tab)
        case datasetLoaded(DatasetSnapshot)
        case datasetFailed(String)
        case projectStoreLoaded([ProjectSummary])
        case projectStoreFailed(String)
        case createProjectTapped
        case projectCreateSaved(ProjectSummary)
        case projectCreateFailed(String)
        case projectTapped(String)
        case projectLoaded(Project)
        case projectLoadFailed(String)
        case projectNameChanged(String)
        case projectTermChanged(String)
        case useFirstNameOnlyChanged(Bool)
        case saveProjectTapped
        case projectSaved(Project, String)
        case projectSaveFailed(String)
        case addStudentTapped
        case deleteStudentTapped(String)
        case studentFirstNameChanged(String, String)
        case studentLastNameChanged(String, String)
        case studentYearLevelChanged(String, StudentYearLevel)
        case subjectToggled(String)
        case achievementLevelChanged(String, String, AchievementLevel?)
        case focusChanged(String, String, String)
        case generateReportsTapped
        case reportsGeneratedAndSaved(Project, String)
        case reportsGenerationFailed(String)
        case reportManualEditChanged(String, String, String)
        case reportLockChanged(String, String, Bool)
        case rosterImportPicked(URL)
        case resultsImportPicked(URL)
        case backupImportPicked(URL)
        case importCancelled
        case importPreviewPrepared(PendingImport)
        case confirmImportTapped
        case importPreviewCancelled
        case importCommitted(Project, String)
        case importFailed(String)
        case prepareBackupTapped
        case prepareReportExportTapped(ImportExportFormat)
        case filePrepared(URL, String)
        case filePreparationFailed(String)
        case fileExportSaved(URL)
        case fileExportCancelled
        case fileExportFailed(String)
        case preparedFileDismissed
    }

    @Dependency(\.datasetClient) var datasetClient
    @Dependency(\.projectStoreClient) var projectStoreClient
    @Dependency(\.commentEngineClient) var commentEngineClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            reduceAppAction(&state, action)
        }
    }
}
