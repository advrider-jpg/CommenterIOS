import CommentEngine
import CommenterAI
import CommenterDomain
import CommenterImportExport
import CommenterPersistence
import ComposableArchitecture
import Foundation

@Reducer
public struct AppFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab = .projects
        public var datasetStatus: DatasetStatus = .notLoaded
        public var projectStorageStatus: ProjectStorageStatus = .notLoaded
        public var aiAvailabilityStatus: AIAvailabilityStatus = .notChecked
        public var projects: [ProjectSummary] = []
        public var invalidProjectRecords: [InvalidProjectRecord] = []
        public var selectedProject: Project?
        public var selectedProjectReadiness: ProjectReadiness?
        public var projectStorageMessage = "Checking local project storage."
        public var workflowMessage = "Open or create a project to manage roster, subjects, results, drafts, backups, and exports."
        public var operationStatus: OperationStatus = .idle
        public var hasUnsavedProjectChanges = false
        public var preparedFile: PreparedFile?
        public var pendingImport: PendingImport?
        public var projectCreationDraft: ProjectCreationDraft?
        public var activeImportKind: ImportWorkflowKind?
        public var pendingEncryptedBackupURL: URL?
        public var pendingAIRevision: PendingAIRevision?
        public var pendingAIRevisions: [PendingAIRevision] = []
        public var isBulkAIRevisionRunning = false
        public var latestReportCheck: ReportCheckResult?
        public var rosterImportState: TabularImportState = .neverImported
        public var resultsImportState: TabularImportState = .neverImported
        public var lastPreparedFiles: [ImportExportFormat: PreparedFileRecord] = [:]

        public init() {}

        public var aiReviewQueueCount: Int {
            var keys = Set(pendingAIRevisions.map { "\($0.studentId)::\($0.subject)" })
            if let pendingAIRevision {
                keys.insert("\(pendingAIRevision.studentId)::\(pendingAIRevision.subject)")
            }
            return keys.count
        }
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
        case deleting
        case preparingFile
        case importing
        case generating
        case failed(String)
    }

    public enum AIAvailabilityStatus: Equatable, Sendable {
        case notChecked
        case checking
        case checked(AIModelAvailability)
        case failed(String)
    }

    public enum OperationStatus: Equatable, Sendable {
        case idle
        case dirty(String)
        case busy(String)
        case saved(String)
        case prepared(String)
        case shared(String)
        case cancelled(String)
        case failed(String)
    }

    public struct PreparedFile: Equatable, Sendable {
        public var url: URL
        public var label: String
        public var format: ImportExportFormat?
        public var preparedAtMilliseconds: Int64?

        public init(url: URL, label: String, format: ImportExportFormat? = nil, preparedAtMilliseconds: Int64? = nil) {
            self.url = url
            self.label = label
            self.format = format
            self.preparedAtMilliseconds = preparedAtMilliseconds
        }
    }

    public struct PreparedFileRecord: Equatable, Sendable {
        public var format: ImportExportFormat
        public var filename: String
        public var label: String
        public var preparedAtMilliseconds: Int64

        public init(format: ImportExportFormat, filename: String, label: String, preparedAtMilliseconds: Int64) {
            self.format = format
            self.filename = filename
            self.label = label
            self.preparedAtMilliseconds = preparedAtMilliseconds
        }
    }

    public struct ProjectCreationDraft: Equatable, Sendable {
        public var name: String
        public var term: String
        public var yearLevel: ProjectYearLevel
        public var useFirstNameOnly: Bool

        public init(name: String = "", term: String = "Term 1", yearLevel: ProjectYearLevel = .year5, useFirstNameOnly: Bool = true) {
            self.name = name
            self.term = term
            self.yearLevel = yearLevel
            self.useFirstNameOnly = useFirstNameOnly
        }

        public var normalizedName: String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var normalizedTerm: String {
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Term 1" : trimmed
        }
    }

    public struct PendingAIRevision: Identifiable, Equatable, Sendable {
        public var id: String
        public var studentId: String
        public var subject: String
        public var originalText: String
        public var originalTextFingerprint: String
        public var proposedText: String
        public var changeSummary: String
        public var validation: ReportValidationSummary
        public var trace: AIReportTrace
        public var reviewWarnings: [String]

        public init(
            id: String,
            studentId: String,
            subject: String,
            originalText: String,
            proposedText: String,
            changeSummary: String,
            validation: ReportValidationSummary,
            trace: AIReportTrace,
            reviewWarnings: [String] = []
        ) {
            self.id = id
            self.studentId = studentId
            self.subject = subject
            self.originalText = originalText
            self.originalTextFingerprint = stableTextFingerprint(originalText)
            self.proposedText = proposedText
            self.changeSummary = changeSummary
            self.validation = validation
            self.trace = trace
            self.reviewWarnings = reviewWarnings
        }
    }

    public struct ReportCheckResult: Equatable, Sendable {
        public var id: String
        public var studentId: String
        public var subject: String
        public var validation: ReportValidationSummary
        public var reviewNotes: [String]

        public init(
            id: String,
            studentId: String,
            subject: String,
            validation: ReportValidationSummary,
            reviewNotes: [String] = []
        ) {
            self.id = id
            self.studentId = studentId
            self.subject = subject
            self.validation = validation
            self.reviewNotes = reviewNotes
        }
    }

    public struct CompletedAIRevision: Equatable, Sendable {
        public var studentId: String
        public var subject: String
        public var originalText: String
        public var result: AIReportRevisionResult

        public init(studentId: String, subject: String, originalText: String, result: AIReportRevisionResult) {
            self.studentId = studentId
            self.subject = subject
            self.originalText = originalText
            self.result = result
        }
    }

    public enum ImportWorkflowKind: Equatable, Sendable {
        case roster
        case results
        case backup
    }

    public enum TabularImportState: Equatable, Sendable {
        case neverImported
        case loaded(count: Int, source: String)
        case validating(String)
        case previewReady(count: Int, source: String)
        case zeroValidRecords(String)
        case failed(String)
        case success(count: Int, source: String)
        case stale(String)
    }

    public struct PendingImport: Equatable, Sendable {
        public var project: Project
        public var title: String
        public var detail: String
        public var successMessage: String
        public var expectedRevision: Int?
        public var recoveryReason: RecoveryReason
        public var kind: ImportWorkflowKind
        public var acceptedRows: Int
        public var sourceFormat: ImportExportFormat?

        public init(
            project: Project,
            title: String,
            detail: String,
            successMessage: String,
            expectedRevision: Int?,
            recoveryReason: RecoveryReason,
            kind: ImportWorkflowKind,
            acceptedRows: Int,
            sourceFormat: ImportExportFormat?
        ) {
            self.project = project
            self.title = title
            self.detail = detail
            self.successMessage = successMessage
            self.expectedRevision = expectedRevision
            self.recoveryReason = recoveryReason
            self.kind = kind
            self.acceptedRows = acceptedRows
            self.sourceFormat = sourceFormat
        }
    }

    public enum Action: Equatable, Sendable {
        case task
        case tabSelected(Tab)
        case datasetLoaded(DatasetSnapshot)
        case datasetFailed(String)
        case aiAvailabilityLoaded(AIModelAvailability)
        case aiAvailabilityFailed(String)
        case projectStoreLoaded(ProjectListDiagnostics)
        case projectStoreFailed(String)
        case createProjectTapped
        case projectCreationNameChanged(String)
        case projectCreationTermChanged(String)
        case projectCreationYearLevelChanged(ProjectYearLevel)
        case projectCreationUseFirstNameOnlyChanged(Bool)
        case projectCreationCancelled
        case confirmCreateProjectTapped
        case projectCreateSaved(ProjectSummary)
        case projectCreateFailed(String)
        case projectTapped(String)
        case projectLoaded(Project)
        case projectLoadFailed(String)
        case projectNameChanged(String)
        case projectTermChanged(String)
        case projectYearLevelChanged(ProjectYearLevel)
        case useFirstNameOnlyChanged(Bool)
        case saveProjectTapped
        case projectSaved(Project, String)
        case projectSaveFailed(String)
        case addStudentTapped
        case deleteStudentTapped(String)
        case studentFirstNameChanged(String, String)
        case studentLastNameChanged(String, String)
        case studentYearLevelChanged(String, StudentYearLevel)
        case studentGenderChanged(String, Gender?)
        case studentPronounsChanged(String, String)
        case studentInternalNoteChanged(String, String)
        case studentAttitudeDescriptorChanged(String, String)
        case subjectToggled(String)
        case subjectSelectAllTapped
        case subjectDeselectAllTapped
        case achievementLevelChanged(String, String, AchievementLevel?)
        case focusChanged(String, String, String)
        case resultEvidenceChanged(String, String, String)
        case resultTextTypeChanged(String, String, String)
        case resultLearningContextChanged(String, String, String)
        case resultReportEmphasisNoteChanged(String, String, String)
        case resultFlagChanged(String, String, String, Bool)
        case resultEnglishFocusTagsChanged(String, String, [String])
        case resultMathProficienciesChanged(String, String, [String])
        case resultMathMindsetTogglesChanged(String, String, [String])
        case resultNextStepGoalsChanged(String, String, [String])
        case generateReportsTapped
        case reportsGeneratedAndSaved(Project, String)
        case reportsGenerationFailed(String)
        case reportManualEditChanged(String, String, String)
        case reportLockChanged(String, String, Bool)
        case reportApprovedForExport(String, String)
        case reportAIPolishTapped(String, String)
        case reportAIPolishCompleted(String, String, AIReportRevisionResult)
        case reportAIPolishFailed(String, String, String)
        case reportAIToneAdjustTapped(String, String)
        case reportAIToneAdjustCompleted(String, String, AIReportRevisionResult)
        case reportAIToneAdjustFailed(String, String, String)
        case reportAIDraftFromEvidenceTapped(String, String)
        case reportAIDraftFromEvidenceCompleted(String, String, AIReportDraftResult)
        case reportAIDraftFromEvidenceFailed(String, String, String)
        case reportBulkAIPolishTapped
        case reportBulkAIPolishProgress(CompletedAIRevision)
        case reportBulkAIPolishCompleted([CompletedAIRevision], [String])
        case reportBulkAIPolishFailed(String)
        case reportBulkAIPolishCancelTapped
        case reportAIRevisionAccepted(String, String)
        case reportAIRevisionRejected(String, String)
        case reportLocalSafetyCheckTapped(String, String)
        case reportLocalSafetyCheckCompleted(String, String, AIReportCritiqueResult)
        case reportLocalSafetyCheckFailed(String, String, String)
        case reportValidationWarningsReviewed(String, String)
        case reportAICritiqueTapped(String, String)
        case reportAICritiqueCompleted(String, String, AIReportCritiqueResult)
        case reportAICritiqueFailed(String, String, String)
        case projectAIToneProfileChanged(AIToneProfile)
        case projectAITargetLengthChanged(ReportLengthTarget)
        case projectAICustomInstructionChanged(String)
        case projectAIForbiddenMentionsChanged([String])
        case projectAIRequiredMentionsChanged([String])
        case projectAISettingsResetBalanced
        case reportAIToneProfileChanged(String, String, AIToneProfile)
        case reportAITargetLengthChanged(String, String, ReportLengthTarget)
        case reportAICustomInstructionChanged(String, String, String)
        case reportAIForbiddenMentionsChanged(String, String, [String])
        case reportAIRequiredMentionsChanged(String, String, [String])
        case reportAIOptionsSavedAsProjectDefaults(String, String)
        case reportAIOptionsReset(String, String)
        case rosterImportPicked(URL)
        case resultsImportPicked(URL)
        case backupImportPicked(URL)
        case encryptedBackupPasswordRequired(URL)
        case backupPasswordEntered(URL, String)
        case backupPasswordCancelled
        case importCancelled
        case importPreviewPrepared(PendingImport)
        case confirmImportTapped
        case importPreviewCancelled
        case importCommitted(Project, String)
        case importFailed(String)
        case prepareBackupTapped
        case prepareReportExportTapped(ImportExportFormat)
        case filePrepared(URL, String, ImportExportFormat, Int64)
        case filePreparationFailed(String)
        case deleteProjectConfirmed(String)
        case projectListDeleteConfirmed(String)
        case projectDeleted(String, [ProjectSummary], String)
        case projectDeleteFailed(String)
        case fileExportSaved(URL)
        case fileExportCancelled
        case fileExportFailed(String)
        case fileShareStarted(URL)
        case fileShareCompleted(URL)
        case fileShareCancelled
        case fileShareFailed(String)
        case preparedFileDismissed
        case operationStatusDismissed
        case copyDiagnosticsTapped
        case copyDiagnosticsSucceeded
        case copyDiagnosticsFailed(String)
    }

    @Dependency(\.datasetClient) var datasetClient
    @Dependency(\.projectStoreClient) var projectStoreClient
    @Dependency(\.commentEngineClient) var commentEngineClient
    @Dependency(\.aiClient) var aiClient
    @Dependency(\.dateClient) var dateClient
    @Dependency(\.clipboardClient) var clipboardClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            reduceAppAction(&state, action)
        }
    }
}
