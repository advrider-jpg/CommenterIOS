import Foundation

public struct Component: Codable, Equatable, Sendable {
    public enum ComponentType: String, Codable, Equatable, Sendable {
        case strength = "Strength"
        case evidence = "Evidence"
        case nextStep = "NextStep"
    }

    public var keyID: String
    public var subject: String
    public var type: ComponentType
    public var level: String
    public var band: String
    public var text: String
    public var strand: String?

    enum CodingKeys: String, CodingKey {
        case keyID = "Key_ID"
        case subject = "Subject"
        case type = "Type"
        case level = "Level"
        case band = "Band"
        case text = "Text"
        case strand = "Strand"
    }

    public init(keyID: String, subject: String, type: ComponentType, level: String, band: String, text: String, strand: String? = nil) {
        self.keyID = keyID
        self.subject = subject
        self.type = type
        self.level = level
        self.band = band
        self.text = text
        self.strand = strand
    }
}

public enum CommentEngineSection: String, Codable, CaseIterable, Sendable {
    case componentBank = "ComponentBank"
    case recipeBank = "RecipeBank"
    case assembledVariants = "AssembledVariants"
    case uniquenessGuard = "UniquenessGuard"
}

public struct RejectionCount: Codable, Equatable, Sendable {
    public var malformed: Int
    public var missingRequiredFields: Int
    public var unsupportedType: Int?
    public var orphaned: Int?

    public init(
        malformed: Int = 0,
        missingRequiredFields: Int = 0,
        unsupportedType: Int? = nil,
        orphaned: Int? = nil
    ) {
        self.malformed = malformed
        self.missingRequiredFields = missingRequiredFields
        self.unsupportedType = unsupportedType
        self.orphaned = orphaned
    }
}

public struct Recipe: Codable, Equatable, Sendable {
    public var recipeID: String
    public var pattern: String
    public var componentMode: String?
    public var requiredTypes: [Component.ComponentType]?

    enum CodingKeys: String, CodingKey {
        case recipeID = "Recipe_ID"
        case pattern = "Pattern"
        case componentMode = "ComponentMode"
        case requiredTypes = "RequiredTypes"
    }

    public init(
        recipeID: String,
        pattern: String,
        componentMode: String? = nil,
        requiredTypes: [Component.ComponentType]? = nil
    ) {
        self.recipeID = recipeID
        self.pattern = pattern
        self.componentMode = componentMode
        self.requiredTypes = requiredTypes
    }
}

public struct AssembledVariant: Codable, Equatable, Sendable {
    public var variantID: String
    public var keyID: String
    public var text: String

    enum CodingKeys: String, CodingKey {
        case variantID = "Variant_ID"
        case keyID = "Key_ID"
        case text = "Text"
    }

    public init(variantID: String, keyID: String, text: String) {
        self.variantID = variantID
        self.keyID = keyID
        self.text = text
    }
}

public struct UniquenessGuard: Codable, Equatable, Sendable {
    public var rule: String
    public var value: Double

    enum CodingKeys: String, CodingKey {
        case rule = "Rule"
        case value = "Value"
    }

    public init(rule: String, value: Double) {
        self.rule = rule
        self.value = value
    }
}

public struct CommentEngineData: Codable, Equatable, Sendable {
    public var componentBank: [Component]
    public var recipeBank: [Recipe]
    public var assembledVariants: [AssembledVariant]
    public var uniquenessGuard: [UniquenessGuard]

    public init(
        componentBank: [Component],
        recipeBank: [Recipe],
        assembledVariants: [AssembledVariant],
        uniquenessGuard: [UniquenessGuard]
    ) {
        self.componentBank = componentBank
        self.recipeBank = recipeBank
        self.assembledVariants = assembledVariants
        self.uniquenessGuard = uniquenessGuard
    }

    enum CodingKeys: String, CodingKey {
        case componentBank = "ComponentBank"
        case recipeBank = "RecipeBank"
        case assembledVariants = "AssembledVariants"
        case uniquenessGuard = "UniquenessGuard"
    }
}

public struct CommentEngineDiagnostics: Codable, Equatable, Sendable {
    public var valid: Bool
    public var errors: [String]
    public var warnings: [String]
    public var componentCount: Int
    public var recipeCount: Int
    public var assembledVariantCount: Int
    public var uniquenessGuardCount: Int
    public var subjects: [String]
    public var bands: [String]
    public var levels: [String]
    public var rejected: [CommentEngineSection: RejectionCount]
    public var uniquenessRules: [String: Double]
    public var placeholderCounts: [String: Int]
    public var datasetHash: String
    public var normalizedSourceHash: String

    public init(
        valid: Bool,
        errors: [String],
        warnings: [String],
        componentCount: Int,
        recipeCount: Int,
        assembledVariantCount: Int,
        uniquenessGuardCount: Int,
        subjects: [String],
        bands: [String],
        levels: [String],
        rejected: [CommentEngineSection: RejectionCount] = CommentEngineSection.defaultRejections,
        uniquenessRules: [String: Double] = [:],
        placeholderCounts: [String: Int] = [:],
        datasetHash: String,
        normalizedSourceHash: String
    ) {
        self.valid = valid
        self.errors = errors
        self.warnings = warnings
        self.componentCount = componentCount
        self.recipeCount = recipeCount
        self.assembledVariantCount = assembledVariantCount
        self.uniquenessGuardCount = uniquenessGuardCount
        self.subjects = subjects
        self.bands = bands
        self.levels = levels
        self.rejected = rejected
        self.uniquenessRules = uniquenessRules
        self.placeholderCounts = placeholderCounts
        self.datasetHash = datasetHash
        self.normalizedSourceHash = normalizedSourceHash
    }
}

public extension CommentEngineSection {
    static let defaultRejections: [CommentEngineSection: RejectionCount] = [
        .componentBank: RejectionCount(unsupportedType: 0),
        .recipeBank: RejectionCount(),
        .assembledVariants: RejectionCount(orphaned: 0),
        .uniquenessGuard: RejectionCount()
    ]
}

public struct ValidatedCommentEngine: Equatable, Sendable {
    public var data: CommentEngineData
    public var diagnostics: CommentEngineDiagnostics

    public init(data: CommentEngineData, diagnostics: CommentEngineDiagnostics) {
        self.data = data
        self.diagnostics = diagnostics
    }
}
