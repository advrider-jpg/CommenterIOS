import CommenterDomain

func hiddenAIExportStrings(_ report: GeneratedReport) -> [String?] {
    var values: [String?] = []
    if let trace = report.aiTrace {
        values.append(trace.traceId)
        values.append(trace.promptId)
        values.append(trace.promptVersion)
        values.append(trace.inputFingerprint)
        values.append(trace.deterministicDraftFingerprint)
        values.append(trace.customInstructionFingerprint)
        values.append(trace.outputFingerprint)
        values.append(trace.errorCode)
        values.append(trace.errorMessage)
    }
    if let validation = report.lastValidation {
        values.append(validation.textFingerprint)
        values.append(contentsOf: validation.findings.map(\.id))
        values.append(contentsOf: validation.findings.map(\.excerpt))
        values.append(contentsOf: validation.findings.map(\.suggestedFix))
    }
    if let review = report.reviewState {
        values.append(review.reviewerDisplayName)
        values.append(review.notes)
        values.append(review.approvalFingerprint)
    }
    values.append(report.currentTextFingerprint)
    values.append(report.approvedTextFingerprint)
    values.append(report.validationWarningReview?.validationFingerprint)
    values.append(report.validationWarningReview?.reviewerDisplayName)
    values.append(report.validationWarningReview?.notes)
    values.append(report.aiOptionsOverride?.customInstruction)
    values.append(contentsOf: report.aiOptionsOverride?.forbiddenMentions ?? [])
    values.append(contentsOf: report.aiOptionsOverride?.requiredMentions ?? [])
    values.append(contentsOf: report.latestAIReviewNotes ?? [])
    values.append(contentsOf: report.revisionHistory?.map(\.id) ?? [])
    values.append(contentsOf: report.revisionHistory?.map(\.traceId) ?? [])
    return values
}
