import Foundation

public enum ProjectYearLevel: String, Codable, Equatable, Sendable {
    case year5 = "Year5"
    case year6 = "Year6"
    case mixed = "Mixed"
}

public enum StudentYearLevel: String, Codable, Equatable, Sendable {
    case year5 = "Year 5"
    case year6 = "Year 6"
}

public enum Gender: String, Codable, Equatable, Sendable {
    case male = "M"
    case female = "F"
    case unspecified = ""
}

public enum AchievementLevel: String, Codable, Equatable, Sendable {
    case beginning = "Beginning"
    case developing = "Developing"
    case atStandard = "At Standard"
    case aboveStandard = "Above Standard"
}

public enum ReportSection: String, Codable, Equatable, CaseIterable, Sendable {
    case general
    case subject
    case dispositions
    case nextSteps
}

public struct ReportLayout: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var order: [ReportSection]
    public var include: [ReportSection: Bool]

    public init(
        enabled: Bool = true,
        order: [ReportSection] = ReportSection.defaultOrder,
        include: [ReportSection: Bool] = ReportSection.defaultIncludes
    ) {
        self.enabled = enabled
        self.order = order
        self.include = include
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case order
        case include
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        order = try container.decodeIfPresent([ReportSection].self, forKey: .order) ?? ReportSection.defaultOrder
        let includeByName = try container.decodeIfPresent([String: Bool].self, forKey: .include) ?? [:]
        include = ReportSection.defaultIncludes
        includeByName.forEach { key, value in
            if let section = ReportSection(rawValue: key) {
                include[section] = value
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(order, forKey: .order)
        try container.encode(Dictionary(uniqueKeysWithValues: include.map { ($0.key.rawValue, $0.value) }), forKey: .include)
    }
}

public extension ReportSection {
    static let defaultOrder: [ReportSection] = [.general, .subject, .dispositions, .nextSteps]
    static let defaultIncludes: [ReportSection: Bool] = [
        .general: true,
        .subject: true,
        .dispositions: true,
        .nextSteps: true
    ]
}

public struct SelectedStrand: Codable, Equatable, Sendable {
    public var name: String
    public var substrands: [String]
    public var allSubstrandsSelected: Bool

    public init(name: String, substrands: [String] = [], allSubstrandsSelected: Bool = false) {
        self.name = name
        self.substrands = substrands
        self.allSubstrandsSelected = allSubstrandsSelected
    }
}

public struct SelectedSubject: Codable, Equatable, Sendable {
    public var name: String
    public var strands: [String: SelectedStrand]
    public var allStrandsSelected: Bool

    public init(name: String, strands: [String: SelectedStrand] = [:], allStrandsSelected: Bool = false) {
        self.name = name
        self.strands = strands
        self.allStrandsSelected = allStrandsSelected
    }
}

public struct ProjectPersistenceMetadata: Codable, Equatable, Sendable {
    public var revision: Int?
    public var savedAt: Int64?
    public var savedBy: String?
    public var fingerprint: String?

    public init(revision: Int? = nil, savedAt: Int64? = nil, savedBy: String? = nil, fingerprint: String? = nil) {
        self.revision = revision
        self.savedAt = savedAt
        self.savedBy = savedBy
        self.fingerprint = fingerprint
    }
}

public struct ProjectAISettings: Codable, Equatable, Sendable {
    public var defaultToneProfile: AIToneProfile
    public var targetLength: ReportLengthTarget
    public var preserveParagraphCount: Bool
    public var allowMinorRestructure: Bool
    public var customInstruction: String?
    public var forbiddenMentions: [String]
    public var requiredMentions: [String]

    public init(
        defaultToneProfile: AIToneProfile = AIToneProfile(),
        targetLength: ReportLengthTarget = .standard,
        preserveParagraphCount: Bool = true,
        allowMinorRestructure: Bool = true,
        customInstruction: String? = nil,
        forbiddenMentions: [String] = [],
        requiredMentions: [String] = []
    ) {
        self.defaultToneProfile = defaultToneProfile
        self.targetLength = targetLength
        self.preserveParagraphCount = preserveParagraphCount
        self.allowMinorRestructure = allowMinorRestructure
        self.customInstruction = customInstruction
        self.forbiddenMentions = forbiddenMentions
        self.requiredMentions = requiredMentions
    }

    public init(reportOptions: AIReportOptions) {
        self.init(
            defaultToneProfile: reportOptions.toneProfile,
            targetLength: reportOptions.targetLength,
            preserveParagraphCount: reportOptions.preserveParagraphCount,
            allowMinorRestructure: reportOptions.allowMinorRestructure,
            customInstruction: reportOptions.customInstruction,
            forbiddenMentions: reportOptions.forbiddenMentions,
            requiredMentions: reportOptions.requiredMentions
        )
    }

    public var reportOptions: AIReportOptions {
        AIReportOptions(
            toneProfile: defaultToneProfile,
            targetLength: targetLength,
            preserveParagraphCount: preserveParagraphCount,
            allowMinorRestructure: allowMinorRestructure,
            customInstruction: customInstruction,
            forbiddenMentions: forbiddenMentions,
            requiredMentions: requiredMentions
        )
    }

    enum CodingKeys: String, CodingKey {
        case defaultToneProfile
        case targetLength
        case preserveParagraphCount
        case allowMinorRestructure
        case customInstruction
        case forbiddenMentions
        case requiredMentions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultToneProfile = try container.decodeIfPresent(AIToneProfile.self, forKey: .defaultToneProfile) ?? AIToneProfile()
        targetLength = try container.decodeIfPresent(ReportLengthTarget.self, forKey: .targetLength) ?? .standard
        preserveParagraphCount = try container.decodeIfPresent(Bool.self, forKey: .preserveParagraphCount) ?? true
        allowMinorRestructure = try container.decodeIfPresent(Bool.self, forKey: .allowMinorRestructure) ?? true
        customInstruction = try container.decodeIfPresent(String.self, forKey: .customInstruction)
        forbiddenMentions = try container.decodeIfPresent([String].self, forKey: .forbiddenMentions) ?? []
        requiredMentions = try container.decodeIfPresent([String].self, forKey: .requiredMentions) ?? []
    }
}

public struct LegacyNotesReview: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case pending
        case keptInternal = "kept-internal"
        case movedSelected = "moved-selected"
        case dismissed
    }

    public var status: Status
    public var reviewedAt: Int64?

    public init(status: Status = .pending, reviewedAt: Int64? = nil) {
        self.status = status
        self.reviewedAt = reviewedAt
    }
}

public struct ProjectMetadata: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var term: String
    public var yearLevel: ProjectYearLevel
    public var createdAt: Int64
    public var updatedAt: Int64
    public var selectedSubjects: [String: SelectedSubject]
    public var useFirstNameOnly: Bool
    public var bandMapping: [String: String]?
    public var allowBandFallback: Bool?
    public var reportLayout: ReportLayout?
    public var legacyNotesReview: LegacyNotesReview?
    public var persistence: ProjectPersistenceMetadata?
    public var aiSettings: ProjectAISettings?

    public init(
        id: String,
        name: String,
        term: String,
        yearLevel: ProjectYearLevel,
        createdAt: Int64,
        updatedAt: Int64,
        selectedSubjects: [String: SelectedSubject] = [:],
        useFirstNameOnly: Bool = false,
        bandMapping: [String: String]? = nil,
        allowBandFallback: Bool? = nil,
        reportLayout: ReportLayout? = nil,
        legacyNotesReview: LegacyNotesReview? = nil,
        persistence: ProjectPersistenceMetadata? = nil,
        aiSettings: ProjectAISettings? = nil
    ) {
        self.id = id
        self.name = name
        self.term = term
        self.yearLevel = yearLevel
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.selectedSubjects = selectedSubjects
        self.useFirstNameOnly = useFirstNameOnly
        self.bandMapping = bandMapping
        self.allowBandFallback = allowBandFallback
        self.reportLayout = reportLayout
        self.legacyNotesReview = legacyNotesReview
        self.persistence = persistence
        self.aiSettings = aiSettings
    }
}

public struct Student: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var firstName: String
    public var lastName: String
    public var gender: Gender?
    public var pronouns: String?
    public var yearLevel: StudentYearLevel
    public var internalTeacherNote: String?
    public var reportEmphasisNote: String?
    public var comments: String?
    public var attitudeDescriptor: String?

    public init(
        id: String,
        firstName: String,
        lastName: String,
        gender: Gender? = nil,
        pronouns: String? = nil,
        yearLevel: StudentYearLevel,
        internalTeacherNote: String? = nil,
        reportEmphasisNote: String? = nil,
        comments: String? = nil,
        attitudeDescriptor: String? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.gender = gender
        self.pronouns = pronouns
        self.yearLevel = yearLevel
        self.internalTeacherNote = internalTeacherNote
        self.reportEmphasisNote = reportEmphasisNote
        self.comments = comments
        self.attitudeDescriptor = attitudeDescriptor
    }
}

public struct AchievementResult: Codable, Equatable, Sendable {
    public var studentId: String
    public var subject: String
    public var achievementLevel: AchievementLevel?
    public var focusStrand: String?
    public var evidenceText: String?
    public var textType: String?
    public var learningContext: String?
    public var internalTeacherNote: String?
    public var reportEmphasisNote: String?
    public var commentsText: String?
    public var flags: [String: Bool]?
    public var englishFocusTags: [String]?
    public var mathProficiencies: [String]?
    public var mathMindsetToggles: [String]?
    public var nextStepGoals: [String]?

    public init(
        studentId: String,
        subject: String,
        achievementLevel: AchievementLevel? = nil,
        focusStrand: String? = nil,
        evidenceText: String? = nil,
        textType: String? = nil,
        learningContext: String? = nil,
        internalTeacherNote: String? = nil,
        reportEmphasisNote: String? = nil,
        commentsText: String? = nil,
        flags: [String: Bool]? = nil,
        englishFocusTags: [String]? = nil,
        mathProficiencies: [String]? = nil,
        mathMindsetToggles: [String]? = nil,
        nextStepGoals: [String]? = nil
    ) {
        self.studentId = studentId
        self.subject = subject
        self.achievementLevel = achievementLevel
        self.focusStrand = focusStrand
        self.evidenceText = evidenceText
        self.textType = textType
        self.learningContext = learningContext
        self.internalTeacherNote = internalTeacherNote
        self.reportEmphasisNote = reportEmphasisNote
        self.commentsText = commentsText
        self.flags = flags
        self.englishFocusTags = englishFocusTags
        self.mathProficiencies = mathProficiencies
        self.mathMindsetToggles = mathMindsetToggles
        self.nextStepGoals = nextStepGoals
    }
}

public enum ReportGenerationMode: String, Codable, Equatable, Sendable {
    case deterministic
    case aiPolishedDeterministic = "ai-polished-deterministic"
    case aiToneAdjusted = "ai-tone-adjusted"
    case aiDraftFromEvidence = "ai-draft-from-evidence"
    case manuallyEdited = "manually-edited"
    case hybrid
}

public struct ReportReviewState: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case notStarted = "not-started"
        case needsTeacherReview = "needs-teacher-review"
        case changesRequested = "changes-requested"
        case approved
        case staleAfterInputChange = "stale-after-input-change"
        case blockedByValidation = "blocked-by-validation"
    }

    public var status: Status
    public var reviewedAt: Int64?
    public var approvedAt: Int64?
    public var reviewerDisplayName: String?
    public var notes: String?
    public var approvalFingerprint: String?

    public init(
        status: Status = .notStarted,
        reviewedAt: Int64? = nil,
        approvedAt: Int64? = nil,
        reviewerDisplayName: String? = nil,
        notes: String? = nil,
        approvalFingerprint: String? = nil
    ) {
        self.status = status
        self.reviewedAt = reviewedAt
        self.approvedAt = approvedAt
        self.reviewerDisplayName = reviewerDisplayName
        self.notes = notes
        self.approvalFingerprint = approvalFingerprint
    }
}

public enum AIModelAvailability: Codable, Equatable, Sendable {
    case available
    case unavailable(AIModelUnavailableReason)
}

public enum AIModelUnavailableReason: String, Codable, Equatable, Sendable {
    case foundationModelsFrameworkMissing = "foundation-models-framework-missing"
    case osVersionTooOld = "os-version-too-old"
    case deviceNotEligible = "device-not-eligible"
    case appleIntelligenceNotEnabled = "apple-intelligence-not-enabled"
    case modelNotReady = "model-not-ready"
    case restricted
    case unknown
}

public enum AIPromptPurpose: String, Codable, Equatable, Sendable {
    case reviseDeterministicDraft = "revise-deterministic-draft"
    case adjustTone = "adjust-tone"
    case draftFromEvidence = "draft-from-evidence"
    case critiqueReport = "critique-report"
    case extractReportSafeFacts = "extract-report-safe-facts"
    case reviewExportConsistency = "review-export-consistency"
}

public enum AITraceOutcome: String, Codable, Equatable, Sendable {
    case completed
    case cancelled
    case blockedByAvailability = "blocked-by-availability"
    case blockedByValidation = "blocked-by-validation"
    case failed
}

public enum ToneAxis: Int, Codable, CaseIterable, Equatable, Sendable {
    case low = -2
    case slightlyLow = -1
    case balanced = 0
    case slightlyHigh = 1
    case high = 2
}

public enum SchoolVoice: String, Codable, CaseIterable, Equatable, Sendable {
    case standard
    case warmPrimary
    case formalReport
    case conciseSystem
    case strengthsBased
}

public struct AIToneProfile: Codable, Equatable, Sendable {
    public var warmth: ToneAxis
    public var specificity: ToneAxis
    public var concision: ToneAxis
    public var formality: ToneAxis
    public var encouragement: ToneAxis
    public var nextStepDirectness: ToneAxis
    public var evidenceAnchoring: ToneAxis
    public var schoolVoice: SchoolVoice

    public init(
        warmth: ToneAxis = .balanced,
        specificity: ToneAxis = .balanced,
        concision: ToneAxis = .balanced,
        formality: ToneAxis = .balanced,
        encouragement: ToneAxis = .balanced,
        nextStepDirectness: ToneAxis = .balanced,
        evidenceAnchoring: ToneAxis = .balanced,
        schoolVoice: SchoolVoice = .standard
    ) {
        self.warmth = warmth
        self.specificity = specificity
        self.concision = concision
        self.formality = formality
        self.encouragement = encouragement
        self.nextStepDirectness = nextStepDirectness
        self.evidenceAnchoring = evidenceAnchoring
        self.schoolVoice = schoolVoice
    }
}

public enum ReportLengthTarget: String, Codable, CaseIterable, Equatable, Sendable {
    case shorter
    case standard
    case fuller
    case strictCharacterLimit = "strict-character-limit"
}

public struct AIReportOptions: Codable, Equatable, Sendable {
    public var toneProfile: AIToneProfile
    public var targetLength: ReportLengthTarget
    public var preserveParagraphCount: Bool
    public var allowMinorRestructure: Bool
    public var customInstruction: String?
    public var forbiddenMentions: [String]
    public var requiredMentions: [String]
    public var includeNextStep: Bool
    public var allowSubjectSpecificVocabulary: Bool

    public init(
        toneProfile: AIToneProfile = AIToneProfile(),
        targetLength: ReportLengthTarget = .standard,
        preserveParagraphCount: Bool = true,
        allowMinorRestructure: Bool = true,
        customInstruction: String? = nil,
        forbiddenMentions: [String] = [],
        requiredMentions: [String] = [],
        includeNextStep: Bool = true,
        allowSubjectSpecificVocabulary: Bool = true
    ) {
        self.toneProfile = toneProfile
        self.targetLength = targetLength
        self.preserveParagraphCount = preserveParagraphCount
        self.allowMinorRestructure = allowMinorRestructure
        self.customInstruction = customInstruction
        self.forbiddenMentions = forbiddenMentions
        self.requiredMentions = requiredMentions
        self.includeNextStep = includeNextStep
        self.allowSubjectSpecificVocabulary = allowSubjectSpecificVocabulary
    }
}

public enum ReportFactSource: String, Codable, Equatable, Sendable {
    case achievementResultEvidence = "achievement-result-evidence"
    case learningContext = "learning-context"
    case reportEmphasisNote = "report-emphasis-note"
    case teacherEnteredAllowedFact = "teacher-entered-allowed-fact"
    case importedResultField = "imported-result-field"
    case deterministicDraft = "deterministic-draft"
}

public enum ReportFactSensitivity: String, Codable, Equatable, Sendable {
    case reportSafe = "report-safe"
    case privateDoNotUse = "private-do-not-use"
    case needsTeacherReview = "needs-teacher-review"
}

public struct ReportSafeFact: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var text: String
    public var source: ReportFactSource
    public var sensitivity: ReportFactSensitivity
    public var approvedForPrompt: Bool

    public init(
        id: String,
        text: String,
        source: ReportFactSource,
        sensitivity: ReportFactSensitivity = .reportSafe,
        approvedForPrompt: Bool = true
    ) {
        self.id = id
        self.text = text
        self.source = source
        self.sensitivity = sensitivity
        self.approvedForPrompt = approvedForPrompt
    }
}

public enum ReportValidationStatus: String, Codable, Equatable, Sendable {
    case passed
    case passedWithWarnings = "passed-with-warnings"
    case blocked
}

public enum ReportValidationSeverity: String, Codable, Equatable, Sendable {
    case warning
    case block
}

public enum ReportValidationCategory: String, Codable, Equatable, Sendable {
    case placeholder
    case name
    case pronoun
    case unsupportedFact = "unsupported-fact"
    case sensitiveInformation = "sensitive-information"
    case forbiddenMention = "forbidden-mention"
    case requiredMention = "required-mention"
    case tone
    case length
    case layout
}

public struct ReportValidationFinding: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var severity: ReportValidationSeverity
    public var category: ReportValidationCategory
    public var message: String
    public var excerpt: String?
    public var suggestedFix: String?

    public init(
        id: String,
        severity: ReportValidationSeverity,
        category: ReportValidationCategory,
        message: String,
        excerpt: String? = nil,
        suggestedFix: String? = nil
    ) {
        self.id = id
        self.severity = severity
        self.category = category
        self.message = message
        self.excerpt = excerpt
        self.suggestedFix = suggestedFix
    }
}

public struct ReportValidationSummary: Codable, Equatable, Sendable {
    public var status: ReportValidationStatus
    public var findings: [ReportValidationFinding]
    public var validatedAt: Int64
    public var textFingerprint: String

    public init(
        status: ReportValidationStatus,
        findings: [ReportValidationFinding],
        validatedAt: Int64,
        textFingerprint: String
    ) {
        self.status = status
        self.findings = findings
        self.validatedAt = validatedAt
        self.textFingerprint = textFingerprint
    }
}

public struct AIReportTrace: Codable, Equatable, Sendable {
    public var traceId: String
    public var promptId: String
    public var promptVersion: String
    public var promptPurpose: AIPromptPurpose
    public var modelAvailabilityAtStart: AIModelAvailability
    public var startedAt: Int64
    public var completedAt: Int64?
    public var inputFingerprint: String
    public var deterministicDraftFingerprint: String?
    public var toneProfile: AIToneProfile
    public var customInstructionFingerprint: String?
    public var outputFingerprint: String?
    public var validationSummary: ReportValidationSummary?
    public var outcome: AITraceOutcome
    public var errorCode: String?
    public var errorMessage: String?

    public init(
        traceId: String,
        promptId: String,
        promptVersion: String,
        promptPurpose: AIPromptPurpose,
        modelAvailabilityAtStart: AIModelAvailability,
        startedAt: Int64,
        completedAt: Int64? = nil,
        inputFingerprint: String,
        deterministicDraftFingerprint: String? = nil,
        toneProfile: AIToneProfile = AIToneProfile(),
        customInstructionFingerprint: String? = nil,
        outputFingerprint: String? = nil,
        validationSummary: ReportValidationSummary? = nil,
        outcome: AITraceOutcome,
        errorCode: String? = nil,
        errorMessage: String? = nil
    ) {
        self.traceId = traceId
        self.promptId = promptId
        self.promptVersion = promptVersion
        self.promptPurpose = promptPurpose
        self.modelAvailabilityAtStart = modelAvailabilityAtStart
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.inputFingerprint = inputFingerprint
        self.deterministicDraftFingerprint = deterministicDraftFingerprint
        self.toneProfile = toneProfile
        self.customInstructionFingerprint = customInstructionFingerprint
        self.outputFingerprint = outputFingerprint
        self.validationSummary = validationSummary
        self.outcome = outcome
        self.errorCode = errorCode
        self.errorMessage = errorMessage
    }
}

public struct ReportRevisionRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var createdAt: Int64
    public var generationMode: ReportGenerationMode
    public var previousTextFingerprint: String?
    public var newTextFingerprint: String
    public var summary: String?
    public var traceId: String?

    public init(
        id: String,
        createdAt: Int64,
        generationMode: ReportGenerationMode,
        previousTextFingerprint: String? = nil,
        newTextFingerprint: String,
        summary: String? = nil,
        traceId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.generationMode = generationMode
        self.previousTextFingerprint = previousTextFingerprint
        self.newTextFingerprint = newTextFingerprint
        self.summary = summary
        self.traceId = traceId
    }
}

public struct ReportWarningReviewRecord: Codable, Equatable, Sendable {
    public var validationFingerprint: String
    public var reviewedAt: Int64
    public var reviewerDisplayName: String?
    public var notes: String?

    public init(
        validationFingerprint: String,
        reviewedAt: Int64,
        reviewerDisplayName: String? = nil,
        notes: String? = nil
    ) {
        self.validationFingerprint = validationFingerprint
        self.reviewedAt = reviewedAt
        self.reviewerDisplayName = reviewerDisplayName
        self.notes = notes
    }
}

public struct GeneratedReport: Codable, Equatable, Sendable {
    public var studentId: String
    public var subject: String
    public var concreteSubject: String?
    public var text: String
    public var variantIds: [String]
    public var trace: String?
    public var isLocked: Bool
    public var manualEdit: String?
    public var generatedAt: Int64
    public var resultFingerprint: String?
    public var generationMode: ReportGenerationMode?
    public var aiTrace: AIReportTrace?
    public var reviewState: ReportReviewState?
    public var currentTextFingerprint: String?
    public var approvedTextFingerprint: String?
    public var lastValidation: ReportValidationSummary?
    public var revisionHistory: [ReportRevisionRecord]?
    public var aiOptionsOverride: AIReportOptions?
    public var latestAIReviewNotes: [String]?
    public var validationWarningReview: ReportWarningReviewRecord?

    public init(
        studentId: String,
        subject: String,
        concreteSubject: String? = nil,
        text: String,
        variantIds: [String] = [],
        trace: String? = nil,
        isLocked: Bool = false,
        manualEdit: String? = nil,
        generatedAt: Int64,
        resultFingerprint: String? = nil,
        generationMode: ReportGenerationMode? = nil,
        aiTrace: AIReportTrace? = nil,
        reviewState: ReportReviewState? = nil,
        currentTextFingerprint: String? = nil,
        approvedTextFingerprint: String? = nil,
        lastValidation: ReportValidationSummary? = nil,
        revisionHistory: [ReportRevisionRecord]? = nil,
        aiOptionsOverride: AIReportOptions? = nil,
        latestAIReviewNotes: [String]? = nil,
        validationWarningReview: ReportWarningReviewRecord? = nil
    ) {
        self.studentId = studentId
        self.subject = subject
        self.concreteSubject = concreteSubject
        self.text = text
        self.variantIds = variantIds
        self.trace = trace
        self.isLocked = isLocked
        self.manualEdit = manualEdit
        self.generatedAt = generatedAt
        self.resultFingerprint = resultFingerprint
        self.generationMode = generationMode
        self.aiTrace = aiTrace
        self.reviewState = reviewState
        self.currentTextFingerprint = currentTextFingerprint
        self.approvedTextFingerprint = approvedTextFingerprint
        self.lastValidation = lastValidation
        self.revisionHistory = revisionHistory
        self.aiOptionsOverride = aiOptionsOverride
        self.latestAIReviewNotes = latestAIReviewNotes
        self.validationWarningReview = validationWarningReview
    }

    public var effectiveGenerationMode: ReportGenerationMode {
        generationMode ?? .deterministic
    }
}

public struct Project: Codable, Equatable, Sendable {
    public var metadata: ProjectMetadata
    public var roster: [Student]
    public var judgements: [JSONValue]
    public var results: [AchievementResult]
    public var reports: [GeneratedReport]

    public init(
        metadata: ProjectMetadata,
        roster: [Student] = [],
        judgements: [JSONValue] = [],
        results: [AchievementResult] = [],
        reports: [GeneratedReport] = []
    ) {
        self.metadata = metadata
        self.roster = roster
        self.judgements = judgements
        self.results = results
        self.reports = reports
    }
}
