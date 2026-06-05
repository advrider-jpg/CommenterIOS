import CommenterDomain
import CommenterReportSafety
import Foundation

func validationContext(for request: AIReportRevisionRequest, text: String, validatedAt: Int64) -> ReportValidationContext? {
    guard let student = request.project.roster.first(where: { $0.id == request.studentId }) else {
        return nil
    }
    let result = request.project.results.first { $0.studentId == request.studentId && $0.subject == request.subject }
    return ReportValidationContext(
        student: student,
        projectMetadata: request.project.metadata,
        subject: request.subject,
        allowedFacts: reportSafeFacts(project: request.project, result: result, deterministicDraft: request.deterministicDraft),
        deterministicDraft: request.deterministicDraft,
        knownStudents: request.project.roster,
        achievementLevel: result?.achievementLevel,
        forbiddenMentions: request.options.forbiddenMentions,
        requiredMentions: request.options.requiredMentions,
        validatedAt: validatedAt
    )
}

func validateRevision(_ text: String, request: AIReportRevisionRequest, validatedAt: Int64) -> ReportValidationSummary {
    guard let context = validationContext(for: request, text: text, validatedAt: validatedAt) else {
        return ReportValidationSummary(
            status: .blocked,
            findings: [
                ReportValidationFinding(
                    id: "missing-student",
                    severity: .block,
                    category: .name,
                    message: "The AI request references a student that is no longer in the project."
                )
            ],
            validatedAt: validatedAt,
            textFingerprint: stableTextFingerprint(text)
        )
    }
    return ReportSafetyValidator.validate(text: text, context: context)
}

func validateDraft(_ text: String, request: AIReportDraftRequest, validatedAt: Int64) -> ReportValidationSummary {
    guard let student = request.project.roster.first(where: { $0.id == request.studentId }) else {
        return ReportValidationSummary(
            status: .blocked,
            findings: [
                ReportValidationFinding(
                    id: "missing-student",
                    severity: .block,
                    category: .name,
                    message: "The AI draft request references a student that is no longer in the project."
                )
            ],
            validatedAt: validatedAt,
            textFingerprint: stableTextFingerprint(text)
        )
    }
    let result = request.project.results.first { $0.studentId == request.studentId && $0.subject == request.subject }
    let context = ReportValidationContext(
        student: student,
        projectMetadata: request.project.metadata,
        subject: request.subject,
        allowedFacts: request.evidence.filter { $0.approvedForPrompt && $0.sensitivity == .reportSafe },
        deterministicDraft: nil,
        knownStudents: request.project.roster,
        achievementLevel: result?.achievementLevel,
        forbiddenMentions: request.options.forbiddenMentions,
        requiredMentions: request.options.requiredMentions,
        validatedAt: validatedAt
    )
    return ReportSafetyValidator.validate(text: text, context: context)
}

func extractLocalReportSafeFacts(rawText: String, source: ReportFactSource) -> [ReportSafeFact] {
    rawText
        .components(separatedBy: CharacterSet(charactersIn: "\n.;"))
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .prefix(12)
        .map { fact in
            ReportSafeFact(
                id: "\(source.rawValue)-\(stableTextFingerprint(fact))",
                text: fact,
                source: source
            )
        }
}

private func reportSafeFacts(project: Project, result: AchievementResult?, deterministicDraft: String) -> [ReportSafeFact] {
    var facts = [
        ReportSafeFact(id: "draft-\(stableTextFingerprint(deterministicDraft))", text: deterministicDraft, source: .deterministicDraft)
    ]
    if let evidence = result?.evidenceText?.trimmingCharacters(in: .whitespacesAndNewlines), !evidence.isEmpty {
        facts.append(ReportSafeFact(id: "evidence-\(stableTextFingerprint(evidence))", text: evidence, source: .achievementResultEvidence))
    }
    if let context = result?.learningContext?.trimmingCharacters(in: .whitespacesAndNewlines), !context.isEmpty {
        facts.append(ReportSafeFact(id: "context-\(stableTextFingerprint(context))", text: context, source: .learningContext))
    }
    if let note = result?.reportEmphasisNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
        facts.append(ReportSafeFact(id: "note-\(stableTextFingerprint(note))", text: note, source: .reportEmphasisNote))
    }
    return facts
}
