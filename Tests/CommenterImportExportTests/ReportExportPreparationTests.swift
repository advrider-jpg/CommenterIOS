import CommentEngine
import CommenterDomain
import CommenterImportExport
import XCTest

final class ReportExportPreparationTests: XCTestCase {
    func testReviewRowsArePrivacySafeAndPreferManualEdits() throws {
        var project = fixtureProject()
        project.reports = [
            readyReport(
                project: project,
                result: project.results[0],
                text: "Generated text should not be exported.",
                manualEdit: "=Manual edit stays visible.",
                generatedAt: 1,
                variantIds: ["internal-variant"],
                trace: "internal trace"
            )
        ]

        let rows = try reportReviewRows(project: project)

        XCTAssertEqual(ReportReviewRow.headers, [
            "Student Name",
            "Year Level",
            "Subject",
            "Specific Subject",
            "Achievement Level",
            "Report Text",
            "Manual Edit Used",
            "AI Review Status",
            "Generated Date",
            "Project Name",
            "Term"
        ])
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].studentName, "Ava Ng")
        XCTAssertEqual(rows[0].reportText, "'=Manual edit stays visible.")
        XCTAssertEqual(rows[0].manualEditUsed, "Yes")
        XCTAssertEqual(rows[0].aiReviewStatus, "Deterministic only")
        XCTAssertEqual(rows[0].generatedDate, "1970-01-01T00:00:00.001Z")
        XCTAssertFalse(rows[0].orderedValues.joined(separator: " ").contains("internal"))
    }

    func testPreparationBlocksAIReportsUntilApproved() throws {
        var project = fixtureProject()
        let text = "Ava writes clearly."
        project.reports = [
            readyReport(
                project: project,
                result: project.results[0],
                text: text,
                generationMode: .aiPolishedDeterministic,
                reviewState: ReportReviewState(status: .needsTeacherReview),
                currentTextFingerprint: stableTextFingerprint(text)
            )
        ]

        XCTAssertThrowsError(try reportReviewRows(project: project)) { error in
            XCTAssertTrue(String(describing: error).contains("AI draft needs teacher review"))
        }

        let fingerprint = stableTextFingerprint(text)
        project.reports[0].reviewState = ReportReviewState(status: .approved, approvedAt: 2, approvalFingerprint: fingerprint)
        project.reports[0].approvedTextFingerprint = fingerprint

        let rows = try reportReviewRows(project: project)
        XCTAssertEqual(rows[0].aiReviewStatus, "AI approved")
    }

    func testPreparationBlocksUnreadyReportsBeforeRowsOrPacketsAreReturned() throws {
        var project = fixtureProject()
        project.reports = [
            readyReport(project: project, result: project.results[0], text: "Ava wrote about [context].")
        ]

        XCTAssertThrowsError(try reportReviewRows(project: project)) { error in
            XCTAssertTrue(String(describing: error).contains("template text"))
        }
        XCTAssertThrowsError(try prepareReportPacket(project: project)) { error in
            XCTAssertTrue(String(describing: error).contains("template text"))
        }

        project.reports = []
        XCTAssertThrowsError(try reportReviewRows(project: project)) { error in
            XCTAssertTrue(String(describing: error).contains("needs a draft report"))
        }
    }

    func testReportPacketFiltersSingleStudentAndPreservesParagraphs() throws {
        var project = fixtureProject(useFirstNameOnly: false)
        let secondStudent = Student(id: "s2", firstName: "Ben", lastName: "Stone", yearLevel: .year6)
        let secondResult = AchievementResult(studentId: "s2", subject: "English", achievementLevel: .aboveStandard, focusStrand: "Reading")
        project.roster.append(secondStudent)
        project.results.append(secondResult)
        project.reports = [
            readyReport(project: project, result: project.results[0], text: "Ava paragraph."),
            readyReport(project: project, result: secondResult, text: " First paragraph. \n\n\n Second paragraph. ")
        ]

        let packet = try prepareReportPacket(project: project, studentId: "s2")
        let allRows = try reportReviewRows(project: project)
        let studentRows = try reportReviewRows(project: project, studentId: "s2")

        XCTAssertNil(packet.summary)
        XCTAssertEqual(packet.students.map(\.displayName), ["Ben Stone"])
        XCTAssertEqual(packet.students[0].sections[0].focus, "Reading")
        XCTAssertEqual(packet.students[0].sections[0].paragraphs, ["First paragraph.", "Second paragraph."])
        XCTAssertEqual(allRows.count, 2)
        XCTAssertEqual(studentRows.count, 1)
        XCTAssertEqual(studentRows[0].studentName, "Ben Stone")
    }


    func testReportExportsUseFormalSubjectDisplayNamesWithoutChangingStorageKeys() throws {
        let result = AchievementResult(studentId: "s1", subject: "Health and P.E.", achievementLevel: .atStandard, focusStrand: "teamwork")
        var project = Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["Health and P.E.": SelectedSubject(name: "Health and P.E.", allStrandsSelected: true)],
                useFirstNameOnly: false
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)],
            results: [result]
        )
        project.reports = [readyReport(project: project, result: result, text: "Ava contributes constructively.")]

        let rows = try reportReviewRows(project: project)
        let packet = try prepareReportPacket(project: project)

        XCTAssertEqual(rows[0].subject, "Health and Physical Education")
        XCTAssertEqual(packet.students[0].sections[0].subject, "Health and Physical Education")
        XCTAssertEqual(project.results[0].subject, "Health and P.E.")
    }

    func testReportExportFilenamesMatchSourceTruthSanitizing() throws {
        var project = fixtureProject(useFirstNameOnly: false)
        project.metadata.name = "Term: Reports/2026?"
        project.roster = [
            Student(id: "s1", firstName: "Ben", lastName: "Stone", yearLevel: .year5)
        ]

        XCTAssertEqual(try reportExportFilename(project: project, format: .xlsx), "Term_ Reports_2026__Report_Review.xlsx")
        XCTAssertEqual(try reportExportFilename(project: project, format: .xls, studentId: "s1"), "Term_ Reports_2026__Ben_Report_Review.xls")
        XCTAssertEqual(try reportExportFilename(project: project, format: .docx, studentId: "s1"), "Term_ Reports_2026__Ben_Reports.docx")

        project.metadata.name = "***"
        project.roster[0].firstName = ""
        XCTAssertEqual(try reportExportFilename(project: project, format: .xlsx, studentId: "s1"), "ReportWriter_Student_Report_Review.xlsx")
    }

    func testSpreadsheetSafeTextAndParagraphs() {
        XCTAssertEqual(spreadsheetSafeText("  =SUM(A1:A2)"), "'  =SUM(A1:A2)")
        XCTAssertEqual(spreadsheetSafeText("@Ava"), "'@Ava")
        XCTAssertEqual(spreadsheetSafeText("ordinary note"), "ordinary note")
        XCTAssertEqual(spreadsheetSafeText(nil), "")
        XCTAssertEqual(reportParagraphs(" First paragraph. \n\n\n Second paragraph. "), ["First paragraph.", "Second paragraph."])
        XCTAssertEqual(reportParagraphs("   "), [])
    }

    private func fixtureProject(useFirstNameOnly: Bool = false) -> Project {
        Project(
            metadata: ProjectMetadata(
                id: "p1",
                name: "Project",
                term: "Term 1",
                yearLevel: .year5,
                createdAt: 1,
                updatedAt: 1,
                selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
                useFirstNameOnly: useFirstNameOnly
            ),
            roster: [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)],
            results: [AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard)]
        )
    }

    private func readyReport(
        project: Project,
        result: AchievementResult,
        text: String,
        manualEdit: String? = nil,
        generatedAt: Int64 = 1,
        variantIds: [String] = [],
        trace: String? = nil,
        generationMode: ReportGenerationMode? = nil,
        reviewState: ReportReviewState? = nil,
        currentTextFingerprint: String? = nil
    ) -> GeneratedReport {
        guard let student = project.roster.first(where: { $0.id == result.studentId }) else {
            XCTFail("Missing fixture student")
            return GeneratedReport(studentId: result.studentId, subject: result.subject, text: text, generatedAt: generatedAt)
        }
        return GeneratedReport(
            studentId: result.studentId,
            subject: result.subject,
            concreteSubject: result.focusStrand ?? result.subject,
            text: text,
            variantIds: variantIds,
            trace: trace,
            manualEdit: manualEdit,
            generatedAt: generatedAt,
            resultFingerprint: buildGenerationFingerprint(
                projectMetadata: project.metadata,
                student: student,
                result: result,
                concreteSubject: result.focusStrand ?? result.subject
            ),
            generationMode: generationMode,
            reviewState: reviewState,
            currentTextFingerprint: currentTextFingerprint
        )
    }
}
