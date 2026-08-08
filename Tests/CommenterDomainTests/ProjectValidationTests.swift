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

    func testStoredValidationCountsContextLimitsAsLiveUTF16Units() {
        var project = fixtureProject()
        project.results[0].textType = String(repeating: "😀", count: 61)

        XCTAssertTrue(
            validateStoredProjectShape(project).issues.contains("Text type / genre must be 120 characters or fewer.")
        )
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

    func testStoredValidationRejectsUnsafePersistenceRevisionAndBlankFingerprint() {
        var project = fixtureProject()
        project.metadata.persistence = ProjectPersistenceMetadata(
            revision: -1,
            savedAt: -1,
            savedBy: " ",
            fingerprint: " "
        )

        let result = validateStoredProjectShape(project)

        XCTAssertTrue(result.issues.contains("Project revision metadata is invalid."))
        XCTAssertTrue(result.issues.contains("Project fingerprint metadata is invalid."))
    }

    func testStoredValidationRejectsBlankStudentIdentifier() {
        var project = fixtureProject()
        project.roster[0].id = " "
        project.results[0].studentId = " "
        project.reports[0].studentId = " "

        let result = validateStoredProjectShape(project)

        XCTAssertTrue(result.issues.contains("Student ids are required."))
    }

    func testStoredValidationAllowsSameNameStudentsWithStableUniqueIdentifiers() {
        var project = fixtureProject()
        project.roster.append(
            Student(id: "s2", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
        )

        XCTAssertTrue(validateStoredProjectShape(project).ok)
    }

    func testStoredValidationRejectsStaleCurrentAndApprovalFingerprints() {
        var project = fixtureProject()
        project.reports[0].currentTextFingerprint = "stale-current"
        project.reports[0].reviewState = ReportReviewState(
            status: .approved,
            reviewedAt: 2,
            approvedAt: 2,
            approvalFingerprint: "stale-approval"
        )
        project.reports[0].approvedTextFingerprint = "stale-approved-text"

        let result = validateStoredProjectShape(project)

        XCTAssertTrue(result.issues.contains("A report's current-text fingerprint does not match its saved text."))
        XCTAssertTrue(result.issues.contains("An approved report does not match its teacher approval fingerprint."))
    }

    func testStoredValidationTreatsAnExplicitlyEmptyManualEditAsCurrentText() {
        var project = fixtureProject()
        project.reports[0].manualEdit = ""
        project.reports[0].currentTextFingerprint = stableTextFingerprint("")

        XCTAssertTrue(validateStoredProjectShape(project).ok)
    }

    func testStoredValidationRejectsNegativeTeacherReviewTimestamp() {
        var project = fixtureProject()
        project.reports[0].reviewedAt = -1

        XCTAssertTrue(
            validateStoredProjectShape(project).issues.contains("A report's teacher-review timestamp is invalid.")
        )
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
