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
        persistence: ProjectPersistenceMetadata? = nil
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
        resultFingerprint: String? = nil
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
