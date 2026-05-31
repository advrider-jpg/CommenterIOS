import CommenterDomain
import XCTest

final class ProjectRulesTests: XCTestCase {
    func testNormalizeReportLayoutPreservesDisabledSubjectSection() {
        let layout = ReportLayout(
            enabled: true,
            order: [.nextSteps],
            include: [.subject: false, .nextSteps: true]
        )

        let normalized = normalizeReportLayout(layout)

        XCTAssertEqual(normalized.order, [.nextSteps, .general, .subject, .dispositions])
        XCTAssertEqual(normalized.include[.subject], false)
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
}
