import CommenterAI
import CommenterDomain
import CommenterReportSafety
import Foundation

public extension AIClient {
    static func configuredForTests(
        availability: AIModelAvailability = .available,
        revisionResult: AIReportRevisionResult? = nil,
        toneAdjustmentResult: AIReportRevisionResult? = nil,
        draftResult: AIReportDraftResult? = nil
    ) -> AIClient {
        AIClient(
            availability: { availability },
            reviseDeterministicDraft: { _ in
                guard let revisionResult else {
                    throw AIClientError.generationNotImplemented
                }
                return revisionResult
            },
            adjustTone: { _ in
                if let toneAdjustmentResult {
                    return toneAdjustmentResult
                }
                guard let revisionResult else {
                    throw AIClientError.generationNotImplemented
                }
                return revisionResult
            },
            draftFromEvidence: { _ in
                guard let draftResult else {
                    throw AIClientError.generationNotImplemented
                }
                return draftResult
            },
            critiqueReport: { request in
                AIReportCritiqueResult(validation: ReportSafetyValidator.validate(text: request.text, context: request.context))
            },
            extractReportSafeFacts: { request in
                let trimmed = request.rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return ReportSafeFactExtractionResult(facts: []) }
                return ReportSafeFactExtractionResult(facts: [
                    ReportSafeFact(id: stableTextFingerprint(trimmed), text: trimmed, source: request.source)
                ])
            }
        )
    }
}
