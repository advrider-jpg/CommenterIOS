import CommenterDomain
import CommenterReportSafety
import Foundation

public struct AIClient: Sendable {
    public var availability: @Sendable () async -> AIModelAvailability
    public var reviseDeterministicDraft: @Sendable (AIReportRevisionRequest) async throws -> AIReportRevisionResult
    public var adjustTone: @Sendable (AIReportRevisionRequest) async throws -> AIReportRevisionResult
    public var draftFromEvidence: @Sendable (AIReportDraftRequest) async throws -> AIReportDraftResult
    public var critiqueReport: @Sendable (AIReportCritiqueRequest) async throws -> AIReportCritiqueResult
    public var extractReportSafeFacts: @Sendable (ReportSafeFactExtractionRequest) async throws -> ReportSafeFactExtractionResult

    public init(
        availability: @escaping @Sendable () async -> AIModelAvailability,
        reviseDeterministicDraft: @escaping @Sendable (AIReportRevisionRequest) async throws -> AIReportRevisionResult,
        adjustTone: @escaping @Sendable (AIReportRevisionRequest) async throws -> AIReportRevisionResult,
        draftFromEvidence: @escaping @Sendable (AIReportDraftRequest) async throws -> AIReportDraftResult,
        critiqueReport: @escaping @Sendable (AIReportCritiqueRequest) async throws -> AIReportCritiqueResult,
        extractReportSafeFacts: @escaping @Sendable (ReportSafeFactExtractionRequest) async throws -> ReportSafeFactExtractionResult
    ) {
        self.availability = availability
        self.reviseDeterministicDraft = reviseDeterministicDraft
        self.adjustTone = adjustTone
        self.draftFromEvidence = draftFromEvidence
        self.critiqueReport = critiqueReport
        self.extractReportSafeFacts = extractReportSafeFacts
    }
}

public extension AIClient {
    static let live = AIClient(
        availability: {
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                return FoundationModelAvailabilityChecker.current()
            }
            return .unavailable(.osVersionTooOld)
            #else
            return .unavailable(.foundationModelsFrameworkMissing)
            #endif
        },
        reviseDeterministicDraft: { request in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await FoundationModelReportGenerator.reviseDeterministicDraft(request)
            }
            throw AIClientError.unavailable(.osVersionTooOld)
            #else
            throw AIClientError.unavailable(.foundationModelsFrameworkMissing)
            #endif
        },
        adjustTone: { request in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await FoundationModelReportGenerator.adjustTone(request)
            }
            throw AIClientError.unavailable(.osVersionTooOld)
            #else
            throw AIClientError.unavailable(.foundationModelsFrameworkMissing)
            #endif
        },
        draftFromEvidence: { request in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await FoundationModelReportGenerator.draftFromEvidence(request)
            }
            throw AIClientError.unavailable(.osVersionTooOld)
            #else
            throw AIClientError.unavailable(.foundationModelsFrameworkMissing)
            #endif
        },
        critiqueReport: { request in
            #if canImport(FoundationModels)
            if #available(iOS 26.0, macOS 26.0, *) {
                return try await FoundationModelReportGenerator.critiqueReport(request)
            }
            throw AIClientError.unavailable(.osVersionTooOld)
            #else
            throw AIClientError.unavailable(.foundationModelsFrameworkMissing)
            #endif
        },
        extractReportSafeFacts: { request in
            ReportSafeFactExtractionResult(facts: extractLocalReportSafeFacts(rawText: request.rawText, source: request.source))
        }
    )

    static let unavailable = AIClient(
        availability: { .unavailable(.foundationModelsFrameworkMissing) },
        reviseDeterministicDraft: { _ in throw AIClientError.unavailable(.foundationModelsFrameworkMissing) },
        adjustTone: { _ in throw AIClientError.unavailable(.foundationModelsFrameworkMissing) },
        draftFromEvidence: { _ in throw AIClientError.unavailable(.foundationModelsFrameworkMissing) },
        critiqueReport: { _ in throw AIClientError.unavailable(.foundationModelsFrameworkMissing) },
        extractReportSafeFacts: { _ in throw AIClientError.unavailable(.foundationModelsFrameworkMissing) }
    )
}

public enum AIClientError: LocalizedError, Equatable {
    case unavailable(AIModelUnavailableReason)
    case generationNotImplemented
    case validationBlocked(ReportValidationSummary)

    public var errorDescription: String? {
        switch self {
        case let .unavailable(reason):
            return "On-device AI is unavailable: \(reason.rawValue)."
        case .generationNotImplemented:
            return "On-device AI generation is not implemented in this build."
        case .validationBlocked:
            return "The AI result was blocked by report validation."
        }
    }
}

public struct AIReportRevisionRequest: Codable, Equatable, Sendable {
    public var project: Project
    public var studentId: String
    public var subject: String
    public var deterministicDraft: String
    public var options: AIReportOptions

    public init(project: Project, studentId: String, subject: String, deterministicDraft: String, options: AIReportOptions = AIReportOptions()) {
        self.project = project
        self.studentId = studentId
        self.subject = subject
        self.deterministicDraft = deterministicDraft
        self.options = options
    }
}

public struct AIReportRevisionResult: Codable, Equatable, Sendable {
    public var revisedText: String
    public var changeSummary: String
    public var validation: ReportValidationSummary
    public var trace: AIReportTrace
    public var reviewWarnings: [String]

    public init(revisedText: String, changeSummary: String, validation: ReportValidationSummary, trace: AIReportTrace, reviewWarnings: [String] = []) {
        self.revisedText = revisedText
        self.changeSummary = changeSummary
        self.validation = validation
        self.trace = trace
        self.reviewWarnings = reviewWarnings
    }
}

public struct AIReportDraftRequest: Codable, Equatable, Sendable {
    public var project: Project
    public var studentId: String
    public var subject: String
    public var evidence: [ReportSafeFact]
    public var options: AIReportOptions

    public init(project: Project, studentId: String, subject: String, evidence: [ReportSafeFact], options: AIReportOptions = AIReportOptions()) {
        self.project = project
        self.studentId = studentId
        self.subject = subject
        self.evidence = evidence
        self.options = options
    }
}

public struct AIReportDraftResult: Codable, Equatable, Sendable {
    public var draftText: String
    public var validation: ReportValidationSummary
    public var trace: AIReportTrace

    public init(draftText: String, validation: ReportValidationSummary, trace: AIReportTrace) {
        self.draftText = draftText
        self.validation = validation
        self.trace = trace
    }
}

public struct AIReportCritiqueRequest: Codable, Equatable, Sendable {
    public var text: String
    public var context: ReportValidationContext

    public init(text: String, context: ReportValidationContext) {
        self.text = text
        self.context = context
    }
}

public struct AIReportCritiqueResult: Codable, Equatable, Sendable {
    public var validation: ReportValidationSummary
    public var reviewNotes: [String]

    public init(validation: ReportValidationSummary, reviewNotes: [String] = []) {
        self.validation = validation
        self.reviewNotes = reviewNotes
    }
}

public struct ReportSafeFactExtractionRequest: Codable, Equatable, Sendable {
    public var rawText: String
    public var source: ReportFactSource

    public init(rawText: String, source: ReportFactSource) {
        self.rawText = rawText
        self.source = source
    }
}

public struct ReportSafeFactExtractionResult: Codable, Equatable, Sendable {
    public var facts: [ReportSafeFact]

    public init(facts: [ReportSafeFact]) {
        self.facts = facts
    }
}
