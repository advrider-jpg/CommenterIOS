import CommenterDomain
import Foundation
import XCTest

final class ProjectAIMetadataTests: XCTestCase {
    func testDecodesGeneratedReportWithoutAIFieldsAsDeterministic() throws {
        let json = Data("""
        {
          "studentId": "s1",
          "subject": "English",
          "text": "Ava writes clearly.",
          "variantIds": ["v1"],
          "isLocked": false,
          "generatedAt": 123,
          "resultFingerprint": "result-fingerprint"
        }
        """.utf8)

        let report = try JSONDecoder().decode(GeneratedReport.self, from: json)

        XCTAssertEqual(report.studentId, "s1")
        XCTAssertEqual(report.variantIds, ["v1"])
        XCTAssertNil(report.generationMode)
        XCTAssertEqual(report.effectiveGenerationMode, .deterministic)
        XCTAssertNil(report.aiTrace)
        XCTAssertNil(report.reviewState)
        XCTAssertNil(report.latestAIReviewNotes)
        XCTAssertNil(report.validationWarningReview)
    }

    func testRoundTripsAIReviewTraceAndValidationFields() throws {
        let summary = ReportValidationSummary(
            status: .passedWithWarnings,
            findings: [
                ReportValidationFinding(
                    id: "unsupported-1",
                    severity: .warning,
                    category: .unsupportedFact,
                    message: "Confirm the claim is supported.",
                    excerpt: "won first place"
                )
            ],
            validatedAt: 10,
            textFingerprint: "text-fingerprint"
        )
        let trace = AIReportTrace(
            traceId: "trace-1",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 8,
            completedAt: 10,
            inputFingerprint: "input-fingerprint",
            deterministicDraftFingerprint: "draft-fingerprint",
            toneProfile: AIToneProfile(warmth: .slightlyHigh, schoolVoice: .warmPrimary),
            outputFingerprint: "text-fingerprint",
            validationSummary: summary,
            outcome: .completed
        )
        let report = GeneratedReport(
            studentId: "s1",
            subject: "English",
            text: "Ava writes clearly.",
            variantIds: ["v1"],
            generatedAt: 123,
            resultFingerprint: "result-fingerprint",
            generationMode: .aiPolishedDeterministic,
            aiTrace: trace,
            reviewState: ReportReviewState(status: .needsTeacherReview),
            currentTextFingerprint: "text-fingerprint",
            lastValidation: summary,
            revisionHistory: [
                ReportRevisionRecord(
                    id: "revision-1",
                    createdAt: 10,
                    generationMode: .aiPolishedDeterministic,
                    previousTextFingerprint: "draft-fingerprint",
                    newTextFingerprint: "text-fingerprint",
                    summary: "Improved flow.",
                    traceId: "trace-1"
                )
            ],
            aiOptionsOverride: AIReportOptions(
                toneProfile: AIToneProfile(warmth: .high, nextStepDirectness: .slightlyHigh),
                targetLength: .shorter,
                customInstruction: "Use a shorter next step.",
                forbiddenMentions: ["lunchtime group"],
                requiredMentions: ["paragraph structure"]
            ),
            latestAIReviewNotes: ["Confirm the evidence detail is classroom-supported."],
            validationWarningReview: ReportWarningReviewRecord(
                validationFingerprint: "text-fingerprint",
                reviewedAt: 11,
                reviewerDisplayName: "Local teacher",
                notes: "Teacher reviewed warning-only findings."
            )
        )

        let encoded = try JSONEncoder().encode(report)
        let decoded = try JSONDecoder().decode(GeneratedReport.self, from: encoded)

        XCTAssertEqual(decoded, report)
        XCTAssertEqual(decoded.effectiveGenerationMode, .aiPolishedDeterministic)
        XCTAssertEqual(decoded.reviewState?.status, .needsTeacherReview)
        XCTAssertEqual(decoded.aiTrace?.validationSummary, summary)
        XCTAssertEqual(decoded.aiOptionsOverride?.targetLength, .shorter)
        XCTAssertEqual(decoded.aiOptionsOverride?.customInstruction, "Use a shorter next step.")
        XCTAssertEqual(decoded.aiOptionsOverride?.forbiddenMentions, ["lunchtime group"])
        XCTAssertEqual(decoded.aiOptionsOverride?.requiredMentions, ["paragraph structure"])
        XCTAssertEqual(decoded.latestAIReviewNotes, ["Confirm the evidence detail is classroom-supported."])
        XCTAssertEqual(decoded.validationWarningReview?.validationFingerprint, "text-fingerprint")
        XCTAssertEqual(decoded.validationWarningReview?.notes, "Teacher reviewed warning-only findings.")
    }

    func testRoundTripsProjectAISettings() throws {
        let settings = ProjectAISettings(
            defaultToneProfile: AIToneProfile(warmth: .high, specificity: .slightlyHigh, concision: .slightlyLow, schoolVoice: .strengthsBased),
            targetLength: .fuller,
            preserveParagraphCount: false,
            allowMinorRestructure: true,
            customInstruction: "Prefer concise next steps.",
            forbiddenMentions: ["lunchtime group"],
            requiredMentions: ["paragraph structure"]
        )
        let metadata = ProjectMetadata(
            id: "p1",
            name: "Room 5",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 1,
            updatedAt: 2,
            selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
            aiSettings: settings
        )

        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ProjectMetadata.self, from: encoded)

        XCTAssertEqual(decoded.aiSettings, settings)
        XCTAssertEqual(decoded.aiSettings?.reportOptions.toneProfile.schoolVoice, .strengthsBased)
        XCTAssertEqual(decoded.aiSettings?.reportOptions.targetLength, .fuller)
        XCTAssertEqual(decoded.aiSettings?.reportOptions.customInstruction, "Prefer concise next steps.")
        XCTAssertEqual(decoded.aiSettings?.reportOptions.forbiddenMentions, ["lunchtime group"])
        XCTAssertEqual(decoded.aiSettings?.reportOptions.requiredMentions, ["paragraph structure"])
    }

    func testDecodesProjectAISettingsWithoutMentionDefaults() throws {
        let json = Data("""
        {
          "defaultToneProfile": {
            "warmth": "high",
            "specificity": "balanced",
            "concision": "balanced",
            "evidenceAnchoring": "balanced",
            "nextStepDirectness": "balanced",
            "schoolVoice": "standard"
          },
          "targetLength": "standard",
          "preserveParagraphCount": true,
          "allowMinorRestructure": true,
          "customInstruction": "Use school voice."
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(ProjectAISettings.self, from: json)

        XCTAssertEqual(decoded.customInstruction, "Use school voice.")
        XCTAssertEqual(decoded.forbiddenMentions, [])
        XCTAssertEqual(decoded.requiredMentions, [])
    }

    func testProjectAISettingsCanBeBuiltFromReportOptions() {
        let options = AIReportOptions(
            toneProfile: AIToneProfile(warmth: .high, specificity: .slightlyHigh),
            targetLength: .fuller,
            preserveParagraphCount: false,
            allowMinorRestructure: false,
            customInstruction: "Use the team voice.",
            forbiddenMentions: ["lunchtime group"],
            requiredMentions: ["paragraph structure"]
        )

        let settings = ProjectAISettings(reportOptions: options)

        XCTAssertEqual(settings.reportOptions, options)
    }
}
