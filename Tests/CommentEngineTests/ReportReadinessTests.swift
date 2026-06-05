import CommentEngine
import CommenterDomain
import XCTest

final class ReportReadinessTests: XCTestCase {
    func testBlocksMissingConcreteFocusForAggregateSubject() {
        var project = fixtureProject(subject: "The Arts")
        project.results = [AchievementResult(studentId: "s1", subject: "The Arts", achievementLevel: .atStandard)]

        let readiness = getResultReadiness(project: project, studentId: "s1", subject: "The Arts")

        XCTAssertEqual(readiness.status, .missingConcreteFocus)
        XCTAssertEqual(readiness.message, "Ava needs the specific subject chosen for The Arts.")
    }

    func testBlocksMissingReportAndUnresolvedPlaceholders() {
        var project = fixtureProject()

        XCTAssertEqual(getReportReadiness(project: project, studentId: "s1", subject: "English").status, .missingReport)

        project.reports = [
            GeneratedReport(studentId: "s1", subject: "English", text: "Ava writes about [context].", generatedAt: 1)
        ]

        let readiness = getReportReadiness(project: project, studentId: "s1", subject: "English")
        XCTAssertEqual(readiness.status, .unresolvedPlaceholder)
        XCTAssertEqual(readiness.placeholders, ["[context]"])
    }

    func testUnresolvedPlaceholderOrderMatchesDraftText() {
        var project = fixtureProject()
        project.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Ava writes about [context] for [Student Name] and returns to [context].",
                generatedAt: 1
            )
        ]

        let readiness = getReportReadiness(project: project, studentId: "s1", subject: "English")

        XCTAssertEqual(readiness.status, .unresolvedPlaceholder)
        XCTAssertEqual(readiness.placeholders, ["[context]", "[Student Name]"])
    }

    func testWhitespaceManualEditOverridesGeneratedTextAndBlocksReadiness() {
        var project = fixtureProject()
        let fingerprint = buildGenerationFingerprint(
            projectMetadata: project.metadata,
            student: project.roster[0],
            result: project.results[0],
            concreteSubject: "English"
        )
        project.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Ava writes clearly.",
                isLocked: true,
                manualEdit: "   ",
                generatedAt: 1,
                resultFingerprint: fingerprint
            )
        ]

        let readiness = getReportReadiness(project: project, studentId: "s1", subject: "English")

        XCTAssertEqual(readiness.status, .missingReport)
        XCTAssertEqual(readiness.report?.manualEdit, "   ")
    }

    func testBlocksLanguageQualityIssue() {
        var project = fixtureProject()
        project.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Ava Ava writes clearly.",
                generatedAt: 1,
                resultFingerprint: buildGenerationFingerprint(projectMetadata: project.metadata, student: project.roster[0], result: project.results[0], concreteSubject: "English")
            )
        ]

        XCTAssertEqual(getReportReadiness(project: project, studentId: "s1", subject: "English").status, .languageQualityIssue)
    }

    func testLanguageLintReportsRepeatedFirstNameLikeV3() {
        let result = lintReportLanguage(
            "Ava Ava writes clearly.",
            displayName: "Ava",
            firstName: "Ava",
            expectedSubjectPronoun: "She"
        )

        XCTAssertEqual(firstBlockingLanguageIssue(result)?.code, "repeated-first-name")
    }

    func testBlocksWrongPronounAndRepeatedWordLanguageIssues() {
        let wrongPronoun = lintReportLanguage(
            "Ava writes clearly. He uses feedback well.",
            displayName: "Ava",
            firstName: "Ava",
            expectedSubjectPronoun: "She"
        )
        XCTAssertEqual(firstBlockingLanguageIssue(wrongPronoun)?.code, "wrong-pronoun")

        let repeatedWord = lintReportLanguage(
            "Ava writes with clear clear detail.",
            displayName: "Ava",
            firstName: "Ava",
            expectedSubjectPronoun: "They"
        )
        XCTAssertEqual(firstBlockingLanguageIssue(repeatedWord)?.code, "repeated-word")
    }

    func testLanguageLintKeepsLongSentenceWarningsSeparateFromExportBlockers() {
        let longSentence = Array(repeating: "Ava explains her ideas clearly", count: 12).joined(separator: " ") + "."

        let result = lintReportLanguage(
            longSentence,
            displayName: "Ava",
            firstName: "Ava",
            expectedSubjectPronoun: "She"
        )

        XCTAssertNil(firstBlockingLanguageIssue(result))
        XCTAssertEqual(result.issues.first?.code, "long-sentence")
        XCTAssertEqual(result.issues.first?.severity, .warning)
        XCTAssertEqual(result.issues.first?.source, .customRule)

        let withoutWarnings = lintReportLanguage(
            longSentence,
            displayName: "Ava",
            firstName: "Ava",
            expectedSubjectPronoun: "She",
            allowWarnings: false
        )
        XCTAssertTrue(withoutWarnings.issues.isEmpty)
    }

    func testBlocksStaleReportsAndAllowsLockedReadyReports() {
        var project = fixtureProject()
        let fingerprint = buildGenerationFingerprint(
            projectMetadata: project.metadata,
            student: project.roster[0],
            result: project.results[0],
            concreteSubject: "English"
        )

        project.reports = [
            GeneratedReport(studentId: "s1", subject: "English", text: "Ava writes clearly.", isLocked: true, generatedAt: 1, resultFingerprint: "old")
        ]
        XCTAssertEqual(getReportReadiness(project: project, studentId: "s1", subject: "English").status, .lockedStale)

        project.reports[0].resultFingerprint = fingerprint
        XCTAssertEqual(getReportReadiness(project: project, studentId: "s1", subject: "English").status, .lockedReady)
        XCTAssertTrue(isReadyForExport(.lockedReady))
    }

    func testProjectReadinessSummarizesExpectedMatrix() {
        var project = fixtureProject()
        project.metadata.selectedSubjects["Mathematics"] = SelectedSubject(name: "Mathematics", allStrandsSelected: true)
        project.results.append(AchievementResult(studentId: "s1", subject: "Mathematics", achievementLevel: .atStandard))

        let fingerprint = buildGenerationFingerprint(
            projectMetadata: project.metadata,
            student: project.roster[0],
            result: project.results[0],
            concreteSubject: "English"
        )
        project.reports = [
            GeneratedReport(studentId: "s1", subject: "English", text: "Ava writes clearly.", generatedAt: 1, resultFingerprint: fingerprint)
        ]

        let readiness = getProjectReadiness(project)
        XCTAssertEqual(readiness.expected, 2)
        XCTAssertEqual(readiness.ready, 1)
        XCTAssertEqual(readiness.blocked.map(\.subject), ["Mathematics"])
    }

    private func fixtureProject(subject: String = "English") -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: [subject: SelectedSubject(name: subject, allStrandsSelected: true)],
                useFirstNameOnly: true
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: subject, achievementLevel: .atStandard)]
        )
    }
}
