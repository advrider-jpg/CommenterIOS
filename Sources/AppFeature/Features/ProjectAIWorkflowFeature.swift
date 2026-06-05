import CommentEngine
import CommenterAI
import CommenterDomain
import CommenterReportSafety
import ComposableArchitecture
import Foundation

private struct BulkAIPolishCancelID: Hashable {}

extension AppFeature {
    func reduceProjectAIWorkflow(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .reportAIPolishTapped(studentId, subject):
            guard state.pendingImport == nil, !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before requesting an AI revision.")
                return .none
            }
            guard !state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("Cancel or finish the running bulk AI revision before requesting a single AI revision.")
                return .none
            }
            guard case .checked(.available) = state.aiAvailabilityStatus else {
                state.operationStatus = .failed(aiUnavailableMessage(status: state.aiAvailabilityStatus))
                return .none
            }
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a generated draft before requesting an AI revision.")
                return .none
            }
            guard !report.isLocked else {
                state.operationStatus = .failed("Unlock this draft before requesting an AI revision.")
                return .none
            }
            let currentText = report.exportText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentText.isEmpty else {
                state.operationStatus = .failed("A draft must contain report text before AI can revise it.")
                return .none
            }
            state.pendingAIRevision = nil
            state.latestReportCheck = nil
            state.operationStatus = .busy("Requesting an on-device AI revision for teacher review.")
            let requestOriginalText = report.exportText
            let request = AIReportRevisionRequest(
                project: project,
                studentId: studentId,
                subject: subject,
                deterministicDraft: requestOriginalText,
                options: report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
            )
            return .run { send in
                do {
                    let result = try await aiClient.reviseDeterministicDraft(request)
                    await send(.reportAIPolishCompleted(studentId, subject, requestOriginalText, result))
                } catch {
                    await send(.reportAIPolishFailed(studentId, subject, error.localizedDescription))
                }
            }

        case let .reportAIPolishCompleted(studentId, subject, originalText, result):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("The AI revision returned after the draft was no longer open.")
                return .none
            }
            guard isCurrentDraftUnchanged(report, since: originalText) else {
                state.operationStatus = .failed(staleAICompletionMessage(kind: "revision"))
                return .none
            }
            let pending = PendingAIRevision(
                id: result.trace.traceId,
                studentId: studentId,
                subject: subject,
                originalText: originalText,
                proposedText: result.revisedText,
                changeSummary: result.changeSummary,
                validation: result.validation,
                trace: result.trace,
                reviewWarnings: result.reviewWarnings
            )
            state.pendingAIRevision = pending
            state.pendingAIRevisions.removeAll { $0.studentId == studentId && $0.subject == subject }
            state.latestReportCheck = ReportCheckResult(
                id: "ai-preview-\(pending.id)",
                studentId: studentId,
                subject: subject,
                validation: result.validation,
                reviewNotes: result.reviewWarnings
            )
            if result.validation.status == .blocked {
                state.operationStatus = .prepared("AI returned a preview, but validation blockers must be fixed before it can be accepted.")
            } else {
                state.operationStatus = .prepared("AI revision preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
            }
            return .none

        case let .reportAIPolishFailed(studentId, subject, message):
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .failed("AI revision did not change the draft: \(message)")
            return .none

        case let .reportAIToneAdjustTapped(studentId, subject):
            guard state.pendingImport == nil, !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before requesting an AI tone adjustment.")
                return .none
            }
            guard !state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("Cancel or finish the running bulk AI revision before requesting an AI tone adjustment.")
                return .none
            }
            guard case .checked(.available) = state.aiAvailabilityStatus else {
                state.operationStatus = .failed(aiUnavailableMessage(status: state.aiAvailabilityStatus))
                return .none
            }
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a generated draft before requesting an AI tone adjustment.")
                return .none
            }
            guard !report.isLocked else {
                state.operationStatus = .failed("Unlock this draft before requesting an AI tone adjustment.")
                return .none
            }
            let currentText = report.exportText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentText.isEmpty else {
                state.operationStatus = .failed("A draft must contain report text before AI can adjust its tone.")
                return .none
            }
            state.pendingAIRevision = nil
            state.latestReportCheck = nil
            state.operationStatus = .busy("Requesting an on-device AI tone adjustment for teacher review.")
            let requestOriginalText = report.exportText
            let request = AIReportRevisionRequest(
                project: project,
                studentId: studentId,
                subject: subject,
                deterministicDraft: requestOriginalText,
                options: report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
            )
            return .run { send in
                do {
                    let result = try await aiClient.adjustTone(request)
                    await send(.reportAIToneAdjustCompleted(studentId, subject, requestOriginalText, result))
                } catch {
                    await send(.reportAIToneAdjustFailed(studentId, subject, error.localizedDescription))
                }
            }

        case let .reportAIToneAdjustCompleted(studentId, subject, originalText, result):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("The AI tone adjustment returned after the draft was no longer open.")
                return .none
            }
            guard isCurrentDraftUnchanged(report, since: originalText) else {
                state.operationStatus = .failed(staleAICompletionMessage(kind: "tone adjustment"))
                return .none
            }
            let pending = PendingAIRevision(
                id: result.trace.traceId,
                studentId: studentId,
                subject: subject,
                originalText: originalText,
                proposedText: result.revisedText,
                changeSummary: result.changeSummary,
                validation: result.validation,
                trace: result.trace,
                reviewWarnings: result.reviewWarnings
            )
            state.pendingAIRevision = pending
            state.pendingAIRevisions.removeAll { $0.studentId == studentId && $0.subject == subject }
            state.latestReportCheck = ReportCheckResult(
                id: "ai-tone-preview-\(pending.id)",
                studentId: studentId,
                subject: subject,
                validation: result.validation,
                reviewNotes: result.reviewWarnings
            )
            if result.validation.status == .blocked {
                state.operationStatus = .prepared("AI returned a tone-adjusted preview, but validation blockers must be fixed before it can be accepted.")
            } else {
                state.operationStatus = .prepared("AI tone-adjusted preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
            }
            return .none

        case let .reportAIToneAdjustFailed(studentId, subject, message):
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .failed("AI tone adjustment did not change the draft: \(message)")
            return .none

        case let .reportAIDraftFromEvidenceTapped(studentId, subject):
            guard state.pendingImport == nil, !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before requesting an AI evidence draft.")
                return .none
            }
            guard !state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("Cancel or finish the running bulk AI revision before requesting an AI evidence draft.")
                return .none
            }
            guard case .checked(.available) = state.aiAvailabilityStatus else {
                state.operationStatus = .failed(aiUnavailableMessage(status: state.aiAvailabilityStatus))
                return .none
            }
            guard matchingPendingRevision(state, studentId: studentId, subject: subject) == nil else {
                state.operationStatus = .failed("Accept or reject the waiting AI preview before requesting another AI draft.")
                return .none
            }
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a generated draft before requesting an AI evidence draft.")
                return .none
            }
            guard !report.isLocked else {
                state.operationStatus = .failed("Unlock this draft before requesting an AI evidence draft.")
                return .none
            }
            let result = project.results.first { $0.studentId == studentId && $0.subject == subject }
            let evidence = reportSafeFacts(project: project, result: result, report: report)
                .filter { $0.source != .deterministicDraft && $0.approvedForPrompt && $0.sensitivity == .reportSafe }
            guard !evidence.isEmpty else {
                state.operationStatus = .failed("Add report-safe evidence, learning context, or a report emphasis note before requesting an AI evidence draft.")
                return .none
            }
            state.pendingAIRevision = nil
            state.latestReportCheck = nil
            state.operationStatus = .busy("Requesting an on-device AI draft from report-safe evidence for teacher review.")
            let requestOriginalText = report.exportText
            let request = AIReportDraftRequest(
                project: project,
                studentId: studentId,
                subject: subject,
                evidence: evidence,
                options: selectedReportAIOptions(state, studentId: studentId, subject: subject)
            )
            return .run { send in
                do {
                    let result = try await aiClient.draftFromEvidence(request)
                    await send(.reportAIDraftFromEvidenceCompleted(studentId, subject, requestOriginalText, result))
                } catch {
                    await send(.reportAIDraftFromEvidenceFailed(studentId, subject, error.localizedDescription))
                }
            }

        case let .reportAIDraftFromEvidenceCompleted(studentId, subject, originalText, result):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("The AI evidence draft returned after the draft was no longer open.")
                return .none
            }
            guard isCurrentDraftUnchanged(report, since: originalText) else {
                state.operationStatus = .failed(staleAICompletionMessage(kind: "evidence draft"))
                return .none
            }
            let pending = PendingAIRevision(
                id: result.trace.traceId,
                studentId: studentId,
                subject: subject,
                originalText: originalText,
                proposedText: result.draftText,
                changeSummary: "Drafted from report-safe evidence.",
                validation: result.validation,
                trace: result.trace
            )
            state.pendingAIRevision = pending
            state.pendingAIRevisions.removeAll { $0.studentId == studentId && $0.subject == subject }
            state.latestReportCheck = ReportCheckResult(
                id: "ai-draft-preview-\(pending.id)",
                studentId: studentId,
                subject: subject,
                validation: result.validation,
                reviewNotes: []
            )
            if result.validation.status == .blocked {
                state.operationStatus = .prepared("AI returned an evidence draft preview, but validation blockers must be fixed before it can be accepted.")
            } else {
                state.operationStatus = .prepared("AI evidence draft preview is ready. Accepting it updates the local draft but still requires teacher approval before export.")
            }
            return .none

        case let .reportAIDraftFromEvidenceFailed(studentId, subject, message):
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .failed("AI evidence draft did not change the draft: \(message)")
            return .none

        case .reportBulkAIPolishTapped:
            guard state.pendingImport == nil, !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before requesting bulk AI revisions.")
                return .none
            }
            guard !state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("Bulk AI revision is already running.")
                return .none
            }
            guard case .checked(.available) = state.aiAvailabilityStatus else {
                state.operationStatus = .failed(aiUnavailableMessage(status: state.aiAvailabilityStatus))
                return .none
            }
            guard let project = state.selectedProject else {
                state.operationStatus = .failed("Open a project before requesting bulk AI revisions.")
                return .none
            }
            let eligibleReports = project.reports.filter { report in
                !report.isLocked && !report.exportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            guard !eligibleReports.isEmpty else {
                state.operationStatus = .failed("No unlocked draft reports are eligible for bulk AI revision.")
                return .none
            }
            state.pendingAIRevision = nil
            state.latestReportCheck = nil
            state.isBulkAIRevisionRunning = true
            state.operationStatus = .busy("Requesting bulk on-device AI revisions for teacher review.")
            return .run { send in
                var completed: [CompletedAIRevision] = []
                var failures: [String] = []
                for report in eligibleReports {
                    try Task.checkCancellation()
                    let request = AIReportRevisionRequest(
                        project: project,
                        studentId: report.studentId,
                        subject: report.subject,
                        deterministicDraft: report.exportText,
                        options: report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
                    )
                    do {
                        let result = try await aiClient.reviseDeterministicDraft(request)
                        try Task.checkCancellation()
                        let completedItem = CompletedAIRevision(studentId: report.studentId, subject: report.subject, originalText: report.exportText, result: result)
                        completed.append(completedItem)
                        await send(.reportBulkAIPolishProgress(completedItem))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        failures.append("\(report.studentId) / \(report.subject): \(error.localizedDescription)")
                    }
                }
                await send(.reportBulkAIPolishCompleted(completed, failures))
            }
            .cancellable(id: BulkAIPolishCancelID(), cancelInFlight: true)

        case let .reportBulkAIPolishProgress(completed):
            appendBulkAIPreview(&state, completed: completed)
            let count = state.pendingAIRevisions.count
            state.operationStatus = .busy("Bulk AI revision queued \(count) teacher-review \(count == 1 ? "preview" : "previews").")
            return .none

        case let .reportBulkAIPolishCompleted(completed, failures):
            state.isBulkAIRevisionRunning = false
            guard !completed.isEmpty else {
                state.operationStatus = .failed(
                    failures.isEmpty
                        ? "Bulk AI revision returned no previews and did not change the project."
                        : "Bulk AI revision returned no previews: \(failures.joined(separator: " | "))"
                )
                return .none
            }
            let previews = completed.map { item in
                PendingAIRevision(
                    id: pendingAIRevisionId(
                        traceId: item.result.trace.traceId,
                        studentId: item.studentId,
                        subject: item.subject
                    ),
                    studentId: item.studentId,
                    subject: item.subject,
                    originalText: item.originalText,
                    proposedText: item.result.revisedText,
                    changeSummary: item.result.changeSummary,
                    validation: item.result.validation,
                    trace: item.result.trace,
                    reviewWarnings: item.result.reviewWarnings
                )
            }
            let completedKeys = Set(previews.map { "\($0.studentId)::\($0.subject)" })
            state.pendingAIRevision = nil
            state.pendingAIRevisions.removeAll { completedKeys.contains("\($0.studentId)::\($0.subject)") }
            state.pendingAIRevisions.append(contentsOf: previews)
            if let first = previews.first {
                state.latestReportCheck = ReportCheckResult(
                    id: "bulk-preview-\(first.id)",
                    studentId: first.studentId,
                    subject: first.subject,
                    validation: first.validation,
                    reviewNotes: first.reviewWarnings
                )
            }
            let failureSuffix = failures.isEmpty ? "" : " \(failures.count) draft \(failures.count == 1 ? "failed" : "failed") and stayed unchanged."
            state.operationStatus = .prepared("\(previews.count) AI revision \(previews.count == 1 ? "preview is" : "previews are") ready for teacher review.\(failureSuffix)")
            return .none

        case let .reportBulkAIPolishFailed(message):
            state.isBulkAIRevisionRunning = false
            state.operationStatus = .failed("Bulk AI revision did not change the project: \(message)")
            return .none

        case .reportBulkAIPolishCancelTapped:
            guard state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("No bulk AI revision is currently running.")
                return .none
            }
            state.isBulkAIRevisionRunning = false
            let queuedCount = state.pendingAIRevisions.count
            let suffix = queuedCount == 0
                ? " No AI previews were queued."
                : " \(queuedCount) completed \(queuedCount == 1 ? "preview remains" : "previews remain") available for teacher review."
            state.operationStatus = .cancelled("Bulk AI revision cancelled. Queued drafts were left unchanged.\(suffix)")
            return .cancel(id: BulkAIPolishCancelID())

        case let .reportAIRevisionAccepted(studentId, subject):
            guard let pending = matchingPendingRevision(state, studentId: studentId, subject: subject) else {
                state.operationStatus = .failed("No AI revision preview is waiting for this draft.")
                return .none
            }
            guard pending.validation.status != .blocked else {
                state.operationStatus = .failed("This AI revision has validation blockers and cannot be accepted.")
                return .none
            }
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("The draft is no longer open, so the AI revision was not applied.")
                return .none
            }
            guard stableTextFingerprint(report.exportText) == pending.originalTextFingerprint else {
                clearPendingAIRevision(&state, studentId: studentId, subject: subject)
                state.operationStatus = .failed("The draft changed after the AI preview was created. Request a new revision before accepting.")
                return .none
            }
            let now = dateClient.nowMilliseconds()
            updateReport(&state, studentId: studentId, subject: subject) { report in
                let newFingerprint = stableTextFingerprint(pending.proposedText)
                var trace = pending.trace
                trace.completedAt = trace.completedAt ?? now
                trace.outputFingerprint = newFingerprint
                trace.validationSummary = pending.validation
                trace.outcome = pending.validation.status == .blocked ? .blockedByValidation : .completed

                report.manualEdit = pending.proposedText
                report.generationMode = generationMode(for: pending)
                report.aiTrace = trace
                report.currentTextFingerprint = newFingerprint
                report.approvedTextFingerprint = nil
                report.lastValidation = pending.validation
                report.latestAIReviewNotes = nil
                report.validationWarningReview = nil
                report.reviewState = ReportReviewState(status: .needsTeacherReview, reviewedAt: now)
                var history = report.revisionHistory ?? []
                history.append(
                    ReportRevisionRecord(
                        id: "revision-\(now)-\(newFingerprint)",
                        createdAt: now,
                        generationMode: generationMode(for: pending),
                        previousTextFingerprint: pending.originalTextFingerprint,
                        newTextFingerprint: newFingerprint,
                        summary: pending.changeSummary,
                        traceId: trace.traceId
                    )
                )
                report.revisionHistory = history
            }
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.latestReportCheck = ReportCheckResult(
                id: "accepted-\(pending.id)",
                studentId: studentId,
                subject: subject,
                validation: pending.validation,
                reviewNotes: pending.reviewWarnings
            )
            state.operationStatus = .dirty("AI revision accepted into the local draft. Save the project, then approve the current AI draft before export.")
            return .none

        case let .reportAIRevisionRejected(studentId, subject):
            guard matchingPendingRevision(state, studentId: studentId, subject: subject) != nil else {
                state.operationStatus = .failed("No AI revision preview is waiting for this draft.")
                return .none
            }
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .cancelled("AI revision discarded. The local draft was not changed.")
            return .none

        case let .reportLocalSafetyCheckTapped(studentId, subject):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a draft before running the local safety check.")
                return .none
            }
            guard let context = reportValidationContextForAIReview(project: project, report: report, nowMilliseconds: dateClient.nowMilliseconds()) else {
                state.operationStatus = .failed("The selected draft no longer has a matching student record.")
                return .none
            }
            let validation = ReportSafetyValidator.validate(text: report.exportText, context: context)
            let notes = validation.findings.map { finding in
                if let suggestedFix = finding.suggestedFix {
                    return "\(finding.message) \(suggestedFix)"
                }
                return finding.message
            }
            return .send(.reportLocalSafetyCheckCompleted(studentId, subject, AIReportCritiqueResult(validation: validation, reviewNotes: notes)))

        case let .reportLocalSafetyCheckCompleted(studentId, subject, result):
            updateReport(&state, studentId: studentId, subject: subject) { report in
                report.currentTextFingerprint = result.validation.textFingerprint
                report.lastValidation = result.validation
                report.latestAIReviewNotes = nil
                report.validationWarningReview = nil
                if report.requiresTeacherApprovalForExport, result.validation.status == .blocked {
                    report.reviewState = ReportReviewState(
                        status: .blockedByValidation,
                        reviewedAt: result.validation.validatedAt,
                        notes: result.validation.findings.map(\.message).joined(separator: " ")
                    )
                    report.approvedTextFingerprint = nil
                }
            }
            state.latestReportCheck = ReportCheckResult(
                id: "check-\(studentId)-\(subject)-\(result.validation.textFingerprint)",
                studentId: studentId,
                subject: subject,
                validation: result.validation,
                reviewNotes: result.reviewNotes
            )
            let summary = localCheckSummary(result.validation)
            state.operationStatus = .dirty("\(summary) Save the project to persist the validation record on this device.")
            return .none

        case let .reportValidationWarningsReviewed(studentId, subject):
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a draft with validation warnings before marking warnings reviewed.")
                return .none
            }
            guard let validation = report.lastValidation else {
                state.operationStatus = .failed("Run a local safety check or AI critique before marking warnings reviewed.")
                return .none
            }
            guard validation.status == .passedWithWarnings else {
                state.operationStatus = validation.status == .blocked
                    ? .failed("Validation blockers must be fixed before warnings can be marked reviewed.")
                    : .failed("There are no validation warnings to mark reviewed.")
                return .none
            }
            let reviewedAt = dateClient.nowMilliseconds()
            updateReport(&state, studentId: studentId, subject: subject) { report in
                report.validationWarningReview = ReportWarningReviewRecord(
                    validationFingerprint: validation.textFingerprint,
                    reviewedAt: reviewedAt,
                    reviewerDisplayName: "Local teacher",
                    notes: validation.findings.map(\.message).joined(separator: " ")
                )
            }
            if let latest = state.latestReportCheck,
               latest.studentId == studentId,
               latest.subject == subject,
               latest.validation.textFingerprint == validation.textFingerprint {
                state.latestReportCheck = latest
            }
            state.operationStatus = .dirty("Validation warnings marked reviewed for the current draft. Save to persist the review.")
            return .none

        case let .reportLocalSafetyCheckFailed(studentId, subject, message):
            state.latestReportCheck = nil
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .failed("Local safety check did not change the draft: \(message)")
            return .none

        case let .reportAICritiqueTapped(studentId, subject):
            guard state.pendingImport == nil, !isLongRunningProjectOperation(state.projectStorageStatus) else {
                state.operationStatus = .failed("Finish the current local operation before requesting an AI critique.")
                return .none
            }
            guard !state.isBulkAIRevisionRunning else {
                state.operationStatus = .failed("Cancel or finish the running bulk AI revision before requesting an AI critique.")
                return .none
            }
            guard case .checked(.available) = state.aiAvailabilityStatus else {
                state.operationStatus = .failed(aiUnavailableMessage(status: state.aiAvailabilityStatus))
                return .none
            }
            guard let project = state.selectedProject,
                  let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
            else {
                state.operationStatus = .failed("Open a draft before requesting an AI critique.")
                return .none
            }
            let text = report.exportText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                state.operationStatus = .failed("Draft text is required before AI can critique it.")
                return .none
            }
            guard let context = reportValidationContextForAIReview(project: project, report: report, nowMilliseconds: dateClient.nowMilliseconds()) else {
                state.operationStatus = .failed("The selected draft no longer has a matching student record.")
                return .none
            }
            state.latestReportCheck = nil
            state.operationStatus = .busy("Requesting an on-device AI critique for teacher review.")
            let request = AIReportCritiqueRequest(text: report.exportText, context: context)
            return .run { send in
                do {
                    let result = try await aiClient.critiqueReport(request)
                    await send(.reportAICritiqueCompleted(studentId, subject, result))
                } catch {
                    await send(.reportAICritiqueFailed(studentId, subject, error.localizedDescription))
                }
            }

        case let .reportAICritiqueCompleted(studentId, subject, result):
            updateReport(&state, studentId: studentId, subject: subject) { report in
                report.currentTextFingerprint = result.validation.textFingerprint
                report.lastValidation = result.validation
                report.latestAIReviewNotes = result.reviewNotes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.nilIfEmpty
                report.validationWarningReview = nil
                if report.requiresTeacherApprovalForExport, result.validation.status == .blocked {
                    report.reviewState = ReportReviewState(
                        status: .blockedByValidation,
                        reviewedAt: result.validation.validatedAt,
                        notes: result.validation.findings.map(\.message).joined(separator: " ")
                    )
                    report.approvedTextFingerprint = nil
                }
            }
            state.latestReportCheck = ReportCheckResult(
                id: "ai-critique-\(studentId)-\(subject)-\(result.validation.textFingerprint)",
                studentId: studentId,
                subject: subject,
                validation: result.validation,
                reviewNotes: result.reviewNotes
            )
            let summary = localCheckSummary(result.validation)
            state.operationStatus = .dirty("\(summary) AI critique notes were stored locally for teacher review. Save the project to persist them on this device.")
            return .none

        case let .reportAICritiqueFailed(studentId, subject, message):
            state.latestReportCheck = nil
            clearPendingAIRevision(&state, studentId: studentId, subject: subject)
            state.operationStatus = .failed("AI critique did not change the draft: \(message)")
            return .none

        case let .projectAIToneProfileChanged(profile):
            updateSelectedProject(&state) { project in
                var settings = project.metadata.aiSettings ?? ProjectAISettings()
                settings.defaultToneProfile = profile
                project.metadata.aiSettings = settings
            }
            state.operationStatus = .dirty("Project AI tone defaults changed. Save to persist them on this device.")
            return .none

        case let .projectAITargetLengthChanged(target):
            updateSelectedProject(&state) { project in
                var settings = project.metadata.aiSettings ?? ProjectAISettings()
                settings.targetLength = target
                project.metadata.aiSettings = settings
            }
            state.operationStatus = .dirty("Project AI length default changed. Save to persist it on this device.")
            return .none

        case let .projectAICustomInstructionChanged(instruction):
            updateSelectedProject(&state) { project in
                var settings = project.metadata.aiSettings ?? ProjectAISettings()
                settings.customInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instruction
                project.metadata.aiSettings = settings
            }
            state.operationStatus = .dirty("Project AI instruction changed. Save to persist it on this device.")
            return .none

        case let .projectAIForbiddenMentionsChanged(mentions):
            updateSelectedProject(&state) { project in
                var settings = project.metadata.aiSettings ?? ProjectAISettings()
                settings.forbiddenMentions = cleanedMentionList(mentions)
                project.metadata.aiSettings = settings
            }
            state.operationStatus = .dirty("Project AI do-not-mention defaults changed. Save to persist them on this device.")
            return .none

        case let .projectAIRequiredMentionsChanged(mentions):
            updateSelectedProject(&state) { project in
                var settings = project.metadata.aiSettings ?? ProjectAISettings()
                settings.requiredMentions = cleanedMentionList(mentions)
                project.metadata.aiSettings = settings
            }
            state.operationStatus = .dirty("Project AI required-mention defaults changed. Save to persist them on this device.")
            return .none

        case .projectAISettingsResetBalanced:
            guard state.selectedProject?.metadata.aiSettings != nil else {
                state.operationStatus = .failed("Project AI defaults are already balanced.")
                return .none
            }
            updateSelectedProject(&state) { project in
                project.metadata.aiSettings = nil
            }
            state.operationStatus = .dirty("Project AI defaults reset to balanced settings. Save to persist the reset.")
            return .none

        case let .reportAIToneProfileChanged(studentId, subject, profile):
            let baseOptions = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateReport(&state, studentId: studentId, subject: subject) { report in
                var options = report.aiOptionsOverride ?? baseOptions
                options.toneProfile = profile
                report.aiOptionsOverride = options
            }
            state.operationStatus = .dirty("This draft's AI tone override changed. Save to persist it on this device.")
            return .none

        case let .reportAITargetLengthChanged(studentId, subject, target):
            let baseOptions = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateReport(&state, studentId: studentId, subject: subject) { report in
                var options = report.aiOptionsOverride ?? baseOptions
                options.targetLength = target
                report.aiOptionsOverride = options
            }
            state.operationStatus = .dirty("This draft's AI length override changed. Save to persist it on this device.")
            return .none

        case let .reportAICustomInstructionChanged(studentId, subject, instruction):
            let baseOptions = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateReport(&state, studentId: studentId, subject: subject) { report in
                var options = report.aiOptionsOverride ?? baseOptions
                options.customInstruction = instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : instruction
                report.aiOptionsOverride = options
            }
            state.operationStatus = .dirty("This draft's AI instruction override changed. Save to persist it on this device.")
            return .none

        case let .reportAIForbiddenMentionsChanged(studentId, subject, mentions):
            let baseOptions = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateReport(&state, studentId: studentId, subject: subject) { report in
                var options = report.aiOptionsOverride ?? baseOptions
                options.forbiddenMentions = cleanedMentionList(mentions)
                report.aiOptionsOverride = options
            }
            state.operationStatus = .dirty("This draft's do-not-mention constraints changed. Save to persist them on this device.")
            return .none

        case let .reportAIRequiredMentionsChanged(studentId, subject, mentions):
            let baseOptions = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateReport(&state, studentId: studentId, subject: subject) { report in
                var options = report.aiOptionsOverride ?? baseOptions
                options.requiredMentions = cleanedMentionList(mentions)
                report.aiOptionsOverride = options
            }
            state.operationStatus = .dirty("This draft's required-mention constraints changed. Save to persist them on this device.")
            return .none

        case let .reportAIOptionsSavedAsProjectDefaults(studentId, subject):
            guard state.selectedProject?.reports.contains(where: { $0.studentId == studentId && $0.subject == subject }) == true else {
                state.operationStatus = .failed("Open a draft before saving its AI settings as project defaults.")
                return .none
            }
            let options = selectedReportAIOptions(state, studentId: studentId, subject: subject)
            updateSelectedProject(&state) { project in
                project.metadata.aiSettings = ProjectAISettings(reportOptions: options)
            }
            state.operationStatus = .dirty("This draft's AI settings were saved as project defaults. Save to persist them on this device.")
            return .none

        case let .reportAIOptionsReset(studentId, subject):
            updateReport(&state, studentId: studentId, subject: subject) { report in
                report.aiOptionsOverride = nil
            }
            state.operationStatus = .dirty("This draft now uses the project AI defaults. Save to persist the reset.")
            return .none

        default:
            return .none
        }
    }
}

private func matchingPendingRevision(
    _ state: AppFeature.State,
    studentId: String,
    subject: String
) -> AppFeature.PendingAIRevision? {
    if let pending = state.pendingAIRevision, pending.studentId == studentId, pending.subject == subject {
        return pending
    }
    return state.pendingAIRevisions.first { $0.studentId == studentId && $0.subject == subject }
}

private func clearPendingAIRevision(_ state: inout AppFeature.State, studentId: String, subject: String) {
    if let pending = state.pendingAIRevision, pending.studentId == studentId, pending.subject == subject {
        state.pendingAIRevision = nil
    }
    state.pendingAIRevisions.removeAll { $0.studentId == studentId && $0.subject == subject }
}

private func appendBulkAIPreview(_ state: inout AppFeature.State, completed: AppFeature.CompletedAIRevision) {
    let pending = AppFeature.PendingAIRevision(
        id: pendingAIRevisionId(
            traceId: completed.result.trace.traceId,
            studentId: completed.studentId,
            subject: completed.subject
        ),
        studentId: completed.studentId,
        subject: completed.subject,
        originalText: completed.originalText,
        proposedText: completed.result.revisedText,
        changeSummary: completed.result.changeSummary,
        validation: completed.result.validation,
        trace: completed.result.trace,
        reviewWarnings: completed.result.reviewWarnings
    )
    state.pendingAIRevision = nil
    state.pendingAIRevisions.removeAll { $0.studentId == pending.studentId && $0.subject == pending.subject }
    state.pendingAIRevisions.append(pending)
    state.latestReportCheck = AppFeature.ReportCheckResult(
        id: "bulk-preview-\(pending.id)",
        studentId: pending.studentId,
        subject: pending.subject,
        validation: pending.validation,
        reviewNotes: pending.reviewWarnings
    )
}

private func isCurrentDraftUnchanged(_ report: GeneratedReport, since originalText: String) -> Bool {
    stableTextFingerprint(report.exportText) == stableTextFingerprint(originalText)
}

private func staleAICompletionMessage(kind: String) -> String {
    "The AI \(kind) returned after the draft changed. The stale preview was discarded; request a new preview from the current draft."
}

private func selectedReportAIOptions(
    _ state: AppFeature.State,
    studentId: String,
    subject: String
) -> AIReportOptions {
    guard let project = state.selectedProject,
          let report = project.reports.first(where: { $0.studentId == studentId && $0.subject == subject })
    else {
        return AIReportOptions()
    }
    return report.aiOptionsOverride ?? project.metadata.aiSettings?.reportOptions ?? AIReportOptions()
}

private func pendingAIRevisionId(traceId: String, studentId: String, subject: String) -> String {
    "\(traceId)-\(studentId)-\(stableTextFingerprint(subject))"
}

private func cleanedMentionList(_ mentions: [String]) -> [String] {
    Array(
        Set(mentions.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
    )
    .sorted()
}

private func generationMode(for pending: AppFeature.PendingAIRevision) -> ReportGenerationMode {
    switch pending.trace.promptPurpose {
    case .draftFromEvidence:
        return .aiDraftFromEvidence
    case .adjustTone:
        return .aiToneAdjusted
    case .reviseDeterministicDraft:
        return .aiPolishedDeterministic
    case .critiqueReport, .extractReportSafeFacts, .reviewExportConsistency:
        return .hybrid
    }
}

private func aiUnavailableMessage(status: AppFeature.AIAvailabilityStatus) -> String {
    switch status {
    case .notChecked:
        return "On-device AI has not been checked yet. Deterministic generation remains available."
    case .checking:
        return "On-device AI availability is still being checked. Try again after the check completes."
    case let .checked(.unavailable(reason)):
        return "On-device AI is unavailable on this device: \(reason.rawValue)."
    case .checked(.available):
        return "On-device AI is available."
    case let .failed(message):
        return "On-device AI availability check failed: \(message)"
    }
}

private func localCheckSummary(_ validation: ReportValidationSummary) -> String {
    switch validation.status {
    case .passed:
        return "Local safety check passed with no findings."
    case .passedWithWarnings:
        return "Local safety check found \(validation.findings.count) warning \(validation.findings.count == 1 ? "item" : "items")."
    case .blocked:
        return "Local safety check found validation blockers."
    }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? {
        isEmpty ? nil : self
    }
}
