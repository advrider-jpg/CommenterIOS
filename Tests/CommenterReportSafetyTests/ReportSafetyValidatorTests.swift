import CommenterDomain
import CommenterReportSafety
import XCTest

final class ReportSafetyValidatorTests: XCTestCase {
    func testBlocksTemplatePlaceholders() {
        let summary = ReportSafetyValidator.validate(
            text: "Ava writes about [context] and {{name}}.",
            context: context()
        )

        XCTAssertEqual(summary.status, .blocked)
        XCTAssertEqual(summary.findings.filter { $0.category == .placeholder }.map(\.excerpt), ["[context]", "{{name}}"])
    }

    func testBlocksSensitiveInformationNotPresentInAllowedFacts() {
        let summary = ReportSafetyValidator.validate(
            text: "Ava has ADHD and participates well.",
            context: context(allowedFacts: [ReportSafeFact(id: "1", text: "participates well", source: .achievementResultEvidence)])
        )

        XCTAssertEqual(summary.status, .blocked)
        XCTAssertTrue(summary.findings.contains { $0.category == .sensitiveInformation && $0.excerpt == "ADHD" })
    }

    func testBlocksOtherStudentNamesAndFirstNameOnlyLastNameLeak() {
        let summary = ReportSafetyValidator.validate(
            text: "Ava Ng worked with Ben during writing.",
            context: context(knownStudents: [
                Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5),
                Student(id: "s2", firstName: "Ben", lastName: "Vale", yearLevel: .year5)
            ])
        )

        XCTAssertEqual(summary.status, .blocked)
        XCTAssertTrue(summary.findings.contains { $0.category == .name && $0.excerpt == "Ng" })
        XCTAssertTrue(summary.findings.contains { $0.category == .name && $0.excerpt == "Ben" })
    }

    func testBlocksPronounMismatch() {
        let summary = ReportSafetyValidator.validate(
            text: "Ava writes clearly. He explains ideas aloud.",
            context: context(student: Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5))
        )

        XCTAssertEqual(summary.status, .blocked)
        XCTAssertTrue(summary.findings.contains { $0.category == .pronoun && $0.excerpt == "he" })
    }

    func testWarnsForUnsupportedClaimsButAllowsSupportedFacts() {
        let unsupported = ReportSafetyValidator.validate(
            text: "Ava won first place and writes clearly.",
            context: context(allowedFacts: [ReportSafeFact(id: "1", text: "writes clearly", source: .achievementResultEvidence)])
        )
        XCTAssertEqual(unsupported.status, .passedWithWarnings)
        XCTAssertTrue(unsupported.findings.contains { $0.category == .unsupportedFact })

        let supported = ReportSafetyValidator.validate(
            text: "Ava won first place and writes clearly.",
            context: context(allowedFacts: [
                ReportSafeFact(id: "1", text: "won first place", source: .teacherEnteredAllowedFact),
                ReportSafeFact(id: "2", text: "writes clearly", source: .achievementResultEvidence)
            ])
        )
        XCTAssertFalse(supported.findings.contains { $0.category == .unsupportedFact })
    }

    func testBlocksTeacherForbiddenMentions() {
        let summary = ReportSafetyValidator.validate(
            text: "Ava enjoys the lunchtime group and writes clearly.",
            context: context(forbiddenMentions: ["lunchtime group"])
        )

        XCTAssertEqual(summary.status, .blocked)
        XCTAssertTrue(summary.findings.contains { finding in
            finding.category == .forbiddenMention &&
                finding.excerpt == "lunchtime group" &&
                finding.message.contains("do-not-mention")
        })
    }

    func testBlocksMissingTeacherRequiredMentions() {
        let missing = ReportSafetyValidator.validate(
            text: "Ava writes clearly and reads with confidence.",
            context: context(requiredMentions: ["paragraph structure"])
        )

        XCTAssertEqual(missing.status, .blocked)
        XCTAssertTrue(missing.findings.contains { finding in
            finding.category == .requiredMention &&
                finding.excerpt == "paragraph structure" &&
                finding.message.contains("missing")
        })

        let present = ReportSafetyValidator.validate(
            text: "Ava writes clearly and uses paragraph structure with growing confidence.",
            context: context(requiredMentions: ["paragraph structure"])
        )

        XCTAssertFalse(present.findings.contains { $0.category == .requiredMention })
    }

    func testTextFingerprintIsStable() {
        XCTAssertEqual(stableTextFingerprint("Ava writes clearly."), stableTextFingerprint("Ava writes clearly."))
        XCTAssertNotEqual(stableTextFingerprint("Ava writes clearly."), stableTextFingerprint("Ava writes carefully."))
    }

    private func context(
        student: Student = Student(id: "s1", firstName: "Ava", lastName: "Ng", gender: .female, yearLevel: .year5),
        allowedFacts: [ReportSafeFact] = [],
        knownStudents: [Student] = [],
        forbiddenMentions: [String] = [],
        requiredMentions: [String] = []
    ) -> ReportValidationContext {
        ReportValidationContext(
            student: student,
            projectMetadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: true
            ),
            subject: "English",
            allowedFacts: allowedFacts,
            deterministicDraft: "Ava writes clearly.",
            knownStudents: knownStudents,
            forbiddenMentions: forbiddenMentions,
            requiredMentions: requiredMentions,
            validatedAt: 123
        )
    }
}
