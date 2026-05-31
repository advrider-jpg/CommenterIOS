import CommenterDomain
import CommenterImportExport
import XCTest

final class ProjectImportCommitTests: XCTestCase {
    func testRosterImportPreparesAppendedProjectWithoutClaimingSave() throws {
        let imported = [
            Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        ]

        let change = try projectByApplyingRosterImport(imported, to: fixtureProject(), nowMilliseconds: 42)

        XCTAssertEqual(change.kind, .roster)
        XCTAssertEqual(change.importedCount, 1)
        XCTAssertEqual(change.project.roster.map(\.id), ["s1", "s2"])
        XCTAssertEqual(change.project.metadata.updatedAt, 42)
        XCTAssertEqual(change.project.results.map(\.studentId), ["s1"])
    }

    func testResultsImportMergesByStudentAndSubject() throws {
        let replacement = AchievementResult(
            studentId: "s1",
            subject: "English",
            achievementLevel: .aboveStandard,
            focusStrand: "Writing"
        )
        let added = AchievementResult(
            studentId: "s1",
            subject: "Mathematics",
            achievementLevel: .developing,
            focusStrand: "Number"
        )
        var project = fixtureProject()
        project.metadata.selectedSubjects["Mathematics"] = SelectedSubject(name: "Mathematics", allStrandsSelected: true)

        let change = try projectByApplyingResultsImport([replacement, added], to: project, nowMilliseconds: 99)

        XCTAssertEqual(change.kind, .results)
        XCTAssertEqual(change.importedCount, 2)
        XCTAssertEqual(change.project.results.count, 2)
        XCTAssertEqual(change.project.results.first { $0.subject == "English" }?.achievementLevel, .aboveStandard)
        XCTAssertEqual(change.project.results.first { $0.subject == "Mathematics" }?.achievementLevel, .developing)
        XCTAssertEqual(change.project.metadata.updatedAt, 99)
    }

    func testInvalidImportsLeaveOriginalProjectValueUnchanged() throws {
        let original = fixtureProject()

        XCTAssertThrowsError(try projectByApplyingRosterImport([
            Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
        ], to: original, nowMilliseconds: 2)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.roster.count, 1)
        XCTAssertEqual(original.metadata.updatedAt, 1)

        XCTAssertThrowsError(try projectByApplyingResultsImport([
            AchievementResult(studentId: "missing", subject: "English", achievementLevel: .atStandard)
        ], to: original, nowMilliseconds: 3)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Existing project data was left unchanged"))
        }
        XCTAssertEqual(original.results.count, 1)
        XCTAssertEqual(original.metadata.updatedAt, 1)
    }

    func testEmptyImportsAreExplicitlyRejected() {
        XCTAssertThrowsError(try projectByApplyingRosterImport([], to: fixtureProject(), nowMilliseconds: 1)) { error in
            XCTAssertEqual(error as? ProjectImportCommitError, .emptyRosterImport)
        }
        XCTAssertThrowsError(try projectByApplyingResultsImport([], to: fixtureProject(), nowMilliseconds: 1)) { error in
            XCTAssertEqual(error as? ProjectImportCommitError, .emptyResultsImport)
        }
    }

    func testExistingInvalidProjectIsRejectedBeforeApplyingImport() {
        var invalidProject = fixtureProject()
        invalidProject.results.append(AchievementResult(studentId: "missing", subject: "English", achievementLevel: .atStandard))

        XCTAssertThrowsError(try projectByApplyingRosterImport([
            Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        ], to: invalidProject, nowMilliseconds: 2)) { error in
            XCTAssertTrue(error.localizedDescription.contains("existing project is not valid"))
        }
    }

    private func fixtureProject() -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: false
            ),
            roster: [
                Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
            ],
            results: [
                AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)
            ]
        )
    }
}
