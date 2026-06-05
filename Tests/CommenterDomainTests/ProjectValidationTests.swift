import CommenterDomain
import XCTest

final class ProjectValidationTests: XCTestCase {
    func testValidProjectPassesStoredShapeValidation() {
        XCTAssertTrue(validateStoredProjectShape(fixtureProject()).ok)
    }

    func testStoredValidationRejectsInvalidSelectedSubjectEntries() {
        var project = fixtureProject()
        project.metadata.selectedSubjects = [
            " ": SelectedSubject(name: "English", allStrandsSelected: true),
            "Mathematics": SelectedSubject(name: " ", allStrandsSelected: true)
        ]

        let result = validateStoredProjectShape(project)

        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.issues.contains("Selected subjects must include valid subject entries."))
    }

    func testStoredValidationRejectsDuplicateResultsAndReports() {
        var project = fixtureProject()
        project.results.append(project.results[0])
        project.reports.append(
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: "Second draft.",
                variantIds: ["v2"],
                generatedAt: 2
            )
        )

        let result = validateStoredProjectShape(project)

        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.issues.contains("Result rows must be unique per student and subject."))
        XCTAssertTrue(result.issues.contains("Reports must be unique per student and subject."))
    }

    func testStoredValidationRejectsUnsafeResultContextFields() {
        var project = fixtureProject()
        project.results[0].textType = "persuasive\ntext"
        project.results[0].learningContext = "{{activity}}"

        let result = validateStoredProjectShape(project)

        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.issues.contains("Text type / genre must be a short phrase, not multiple lines."))
        XCTAssertTrue(result.issues.contains("Learning context / activity must not contain template placeholders such as [context] or {Name}."))
    }

    func testStoredValidationRejectsSentenceLikeResultContextFields() {
        var project = fixtureProject()
        project.results[0].textType = "They created a persuasive paragraph"
        project.results[0].learningContext = "Ava solved multi-step problems"

        let result = validateStoredProjectShape(project)

        XCTAssertFalse(result.ok)
        XCTAssertTrue(result.issues.contains("Text type / genre must be a short phrase without leading pronouns."))
        XCTAssertTrue(result.issues.contains("Learning context / activity must be a short phrase, not a sentence."))
    }

    func testStoredValidationTreatsEmptyContextMarkersAsEmpty() {
        var project = fixtureProject()
        project.results[0].textType = "n/a"
        project.results[0].learningContext = "none."

        XCTAssertTrue(validateStoredProjectShape(project).ok)
    }

    func testStoredValidationAllowsDraftContentThatReadinessWillGateLater() {
        var project = fixtureProject()
        project.reports = [
            GeneratedReport(
                studentId: "s1",
                subject: "English",
                text: " ",
                variantIds: ["v1", " "],
                isLocked: false,
                manualEdit: "Keep [context].",
                generatedAt: 1
            )
        ]

        XCTAssertTrue(validateStoredProjectShape(project).ok)
    }

    private func fixtureProject() -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "project-1",
                name: "Room 1",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: true
            ),
            roster: [
                Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
            ],
            results: [
                AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)
            ],
            reports: [
                GeneratedReport(
                    studentId: "s1",
                    subject: "English",
                    text: "Ava writes clearly in English.",
                    variantIds: ["v1"],
                    generatedAt: 1
                )
            ]
        )
    }
}
