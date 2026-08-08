import CommenterDomain
import XCTest

final class ProjectRulesTests: XCTestCase {
    func testNormalizeReportLayoutForcesSubjectSectionLikeV3() {
        let layout = ReportLayout(
            enabled: true,
            order: [.nextSteps],
            include: [.subject: false, .nextSteps: true]
        )

        let normalized = normalizeReportLayout(layout)

        XCTAssertEqual(normalized.order, [.nextSteps, .general, .subject, .dispositions])
        XCTAssertEqual(normalized.include[.subject], true)
    }

    func testNormalizeReportLayoutDeduplicatesMalformedOrder() {
        let layout = ReportLayout(
            enabled: true,
            order: [.subject, .general, .subject],
            include: [.general: true, .subject: true, .dispositions: true, .nextSteps: true]
        )

        let normalized = normalizeReportLayout(layout)

        XCTAssertEqual(normalized.order, [.subject, .general, .dispositions, .nextSteps])
    }

    func testDuplicateStudentIdentityUsesNameAndYearLevel() {
        let roster = [
            Student(id: "1", firstName: " Ada ", lastName: "Lovelace", yearLevel: .year5),
            Student(id: "2", firstName: "ada", lastName: "lovelace", yearLevel: .year5),
            Student(id: "3", firstName: "Ada", lastName: "Lovelace", yearLevel: .year6)
        ]

        XCTAssertEqual(duplicateStudentDisplayKeys(roster: roster), ["ada::lovelace::year 5"])
    }

    func testProjectLimitsRejectOversizedRoster() {
        let metadata = ProjectMetadata(
            id: "project-1",
            name: "Room 1",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 0,
            updatedAt: 0
        )
        let roster = (0...ProjectLimits.students).map {
            Student(id: "\($0)", firstName: "Student", lastName: "\($0)", yearLevel: .year5)
        }
        let project = Project(metadata: metadata, roster: roster)

        XCTAssertTrue(validateProjectSizeLimits(project).contains { $0.code == "too-many-students" })
    }

    func testDerivesProjectYearLevelFromCompleteRosterOnly() {
        let incomplete = Student(id: "draft", firstName: "", lastName: "", yearLevel: .year6)
        let yearFive = Student(id: "five", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
        let yearSix = Student(id: "six", firstName: "Leo", lastName: "Tran", yearLevel: .year6)

        XCTAssertEqual(deriveProjectYearLevel(roster: [incomplete], fallback: .mixed), .mixed)
        XCTAssertEqual(deriveProjectYearLevel(roster: [incomplete, yearFive], fallback: .mixed), .year5)
        XCTAssertEqual(deriveProjectYearLevel(roster: [yearFive, yearSix], fallback: .year5), .mixed)
    }

    func testPersistenceReconciliationKeepsRosterYearLevelTruthful() {
        var project = fixtureProject()
        project.metadata.yearLevel = .year5
        project.roster = [Student(id: "s1", firstName: "Leo", lastName: "Tran", yearLevel: .year6)]

        let reconciled = reconcileProjectForPersistence(project, nowMilliseconds: 50)

        XCTAssertEqual(reconciled.metadata.yearLevel, .year6)
        XCTAssertEqual(reconciled.metadata.updatedAt, 50)
    }

    func testProjectLimitsRejectDeepLegacyJudgementsBeforeEncoding() {
        var nested = JSONValue.null
        for _ in 0...ProjectLimits.jsonMaximumDepth {
            nested = .array([nested])
        }
        var project = fixtureProject()
        project.judgements = [nested]

        let issues = validateProjectSizeLimits(project)

        XCTAssertTrue(issues.contains { $0.code == "project-structure-too-complex" })
    }

    func testProjectLimitsCoverCurriculumSelectionsResultArraysAndTraceData() {
        var project = fixtureProject()
        project.metadata.selectedSubjects["English"] = SelectedSubject(
            name: "English",
            strands: Dictionary(uniqueKeysWithValues: (0...ProjectLimits.strandsPerSubject).map { index in
                ("strand-\(index)", SelectedStrand(name: "Strand \(index)"))
            }),
            allStrandsSelected: false
        )
        project.results[0].nextStepGoals = (0...ProjectLimits.resultArrayItems).map { "goal-\($0)" }
        project.reports[0].trace = String(repeating: "x", count: ProjectLimits.reportTraceBytes + 1)

        let codes = Set(validateProjectSizeLimits(project).map(\.code))

        XCTAssertTrue(codes.contains("too-many-strands"))
        XCTAssertTrue(codes.contains("result-array-too-long"))
        XCTAssertTrue(codes.contains("report-trace-too-large"))
    }

    func testReportTraceLimitUsesPersistedJSONBytes() {
        var project = fixtureProject()
        project.reports[0].trace = String(repeating: "\"", count: ProjectLimits.reportTraceBytes / 2)

        XCTAssertTrue(validateProjectSizeLimits(project).contains { $0.code == "report-trace-too-large" })
    }

    func testCharacterLimitsMatchLiveUTF16CountingForEmoji() {
        var project = fixtureProject()
        project.metadata.name = String(repeating: "😀", count: 61)
        project.results[0].evidenceText = String(repeating: "😀", count: 1_001)
        project.reports[0].text = String(repeating: "😀", count: 4_001)

        let codes = Set(validateProjectSizeLimits(project).map(\.code))

        XCTAssertTrue(codes.contains("project-name-too-long"))
        XCTAssertTrue(codes.contains("result-text-too-long"))
        XCTAssertTrue(codes.contains("report-text-too-long"))
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
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)]
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)],
            reports: [GeneratedReport(studentId: "s1", subject: "English", text: "Ava writes clearly.", generatedAt: 1)]
        )
    }
}
