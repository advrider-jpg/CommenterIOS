import CommenterAI
import CommenterDomain
import CommenterReportSafety
import XCTest

final class AIQualityEvaluationTests: XCTestCase {
    func testAdversarialAIOutputsAreBlockedOrWarnedByDeterministicHarness() {
        let cases: [(String, ReportValidationStatus)] = [
            ("Ava is the best reader in the class and will always succeed.", .passedWithWarnings),
            ("Ava has ADHD and writes with confidence.", .blocked),
            ("Ava writes about [context].", .blocked),
            ("Ava is lazy during writing lessons.", .blocked),
            ("Ava writes clearly. He explains ideas aloud.", .blocked)
        ]

        for (text, expectedStatus) in cases {
            let summary = ReportSafetyValidator.validate(text: text, context: evaluationContext())
            XCTAssertEqual(summary.status, expectedStatus, "Unexpected status for: \(text)")
        }
    }

    func testDraftFromEvidencePromptUsesOnlyApprovedEvidence() {
        let request = AIReportDraftRequest(
            project: evaluationProject(),
            studentId: "s1",
            subject: "English",
            evidence: [
                ReportSafeFact(id: "safe", text: "uses quotations accurately", source: .achievementResultEvidence),
                ReportSafeFact(id: "private", text: "family issue", source: .teacherEnteredAllowedFact, sensitivity: .privateDoNotUse, approvedForPrompt: false)
            ],
            options: AIReportOptions(toneProfile: AIToneProfile(evidenceAnchoring: .high))
        )

        let prompt = AIReportPromptBuilder.draftFromEvidence(request)

        XCTAssertTrue(prompt.prompt.contains("uses quotations accurately"))
        XCTAssertFalse(prompt.prompt.contains("family issue"))
        XCTAssertTrue(prompt.instructions.contains("Use clearly increased evidence anchoring"))
    }

    private func evaluationContext() -> ReportValidationContext {
        ReportValidationContext(
            student: Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5),
            projectMetadata: evaluationProject().metadata,
            subject: "English",
            allowedFacts: [ReportSafeFact(id: "fact", text: "writes with confidence", source: .achievementResultEvidence)],
            deterministicDraft: "Ava writes with confidence.",
            knownStudents: [Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5)],
            achievementLevel: .atStandard,
            validatedAt: 1
        )
    }

    private func evaluationProject() -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Room 5",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: true
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5)]
        )
    }
}
