import CommenterAI
import CommenterAITestSupport
import CommenterDomain
import XCTest

final class AIClientTests: XCTestCase {
    func testUnavailableClientReportsFrameworkMissingAndThrows() async {
        let availability = await AIClient.unavailable.availability()
        XCTAssertEqual(availability, .unavailable(.foundationModelsFrameworkMissing))

        do {
            _ = try await AIClient.unavailable.reviseDeterministicDraft(revisionRequest())
            XCTFail("Expected unavailable AI client to throw.")
        } catch let error as AIClientError {
            XCTAssertEqual(error, .unavailable(.foundationModelsFrameworkMissing))
        } catch {
            XCTFail("Expected AIClientError, got \(error).")
        }
    }

    func testConfiguredClientReturnsConfiguredRevisionResult() async throws {
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 1, textFingerprint: "fp")
        let trace = AIReportTrace(
            traceId: "trace-1",
            promptId: "report.revise.deterministic.v1",
            promptVersion: "1.0.0",
            promptPurpose: .reviseDeterministicDraft,
            modelAvailabilityAtStart: .available,
            startedAt: 1,
            inputFingerprint: "input-fp",
            outputFingerprint: "fp",
            validationSummary: validation,
            outcome: .completed
        )
        let expected = AIReportRevisionResult(
            revisedText: "Ava writes with clear detail.",
            changeSummary: "Improved flow.",
            validation: validation,
            trace: trace
        )
        let client = AIClient.configuredForTests(revisionResult: expected)

        let availability = await client.availability()
        XCTAssertEqual(availability, .available)
        let result = try await client.reviseDeterministicDraft(revisionRequest())

        XCTAssertEqual(result, expected)
    }

    func testConfiguredClientReturnsToneAdjustmentResultSeparately() async throws {
        let validation = ReportValidationSummary(status: .passed, findings: [], validatedAt: 1, textFingerprint: "tone-fp")
        let trace = AIReportTrace(
            traceId: "tone-trace",
            promptId: "report.adjust.tone.v1",
            promptVersion: "1.0.0",
            promptPurpose: .adjustTone,
            modelAvailabilityAtStart: .available,
            startedAt: 1,
            inputFingerprint: "input-fp",
            outputFingerprint: "tone-fp",
            validationSummary: validation,
            outcome: .completed
        )
        let expected = AIReportRevisionResult(
            revisedText: "Ava writes with a warmer, still accurate tone.",
            changeSummary: "Adjusted tone only.",
            validation: validation,
            trace: trace
        )
        let client = AIClient.configuredForTests(toneAdjustmentResult: expected)

        let result = try await client.adjustTone(revisionRequest())

        XCTAssertEqual(result, expected)
    }

    func testConfiguredClientExtractsReportSafeFactsLocally() async throws {
        let client = AIClient.configuredForTests()
        let result = try await client.extractReportSafeFacts(
            ReportSafeFactExtractionRequest(
                rawText: "Uses evidence carefully. Explains thinking aloud.",
                source: .teacherEnteredAllowedFact
            )
        )

        XCTAssertEqual(result.facts.count, 1)
        XCTAssertEqual(result.facts.first?.text, "Uses evidence carefully. Explains thinking aloud.")
        XCTAssertEqual(result.facts.first?.source, .teacherEnteredAllowedFact)
    }

    private func revisionRequest() -> AIReportRevisionRequest {
        let project = Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)]
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
        )
        return AIReportRevisionRequest(
            project: project,
            studentId: "s1",
            subject: "English",
            deterministicDraft: "Ava writes clearly."
        )
    }
}
