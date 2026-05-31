import CommentEngine
import XCTest

final class SubjectMappingTests: XCTestCase {
    func testSubjectCandidateResolutionUsesLiveDatasetSubjectNamesAndSynonyms() throws {
        let data = try ProductionCommentDataset.loadBundled().data
        let subjects = getDatasetSubjects(data)

        XCTAssertTrue(subjects.contains("Health and P.E."))
        XCTAssertEqual(resolveSubjectCandidates(uiSubject: "maths", datasetSubjects: subjects), ["Mathematics"])
        XCTAssertEqual(resolveSubjectCandidates(uiSubject: "HPE", datasetSubjects: subjects), ["Health and P.E."])
        XCTAssertEqual(resolveSubjectCandidates(uiSubject: "Humanities & Social Sciences", datasetSubjects: subjects), ["HASS"])
        XCTAssertEqual(resolveSubjectCandidates(uiSubject: "Not a subject", datasetSubjects: subjects), [])
    }

    func testAggregateSubjectsRequireConcreteFocusBeforeGeneration() throws {
        let data = try ProductionCommentDataset.loadBundled().data

        let arts = resolveSubjectForGeneration(uiSubject: "The Arts", data: data)
        XCTAssertFalse(arts.eligible)
        XCTAssertEqual(arts.candidates, ["Dance", "Drama", "Media Arts", "Music", "Visual Arts"])
        XCTAssertTrue(arts.reason?.contains("needs the specific subject chosen") == true)

        let focusedArts = resolveSubjectForGeneration(uiSubject: "The Arts", data: data, focusStrand: "Music")
        XCTAssertTrue(focusedArts.eligible)
        XCTAssertEqual(focusedArts.selectedDataSubject, "Music")

        let technologies = resolveSubjectForGeneration(uiSubject: "Technologies", data: data, focusStrand: "Digital Technologies")
        XCTAssertTrue(technologies.eligible)
        XCTAssertEqual(technologies.selectedDataSubject, "Digital Technologies")
    }

    func testConcreteFocusOptionsAndMatchingPreserveAggregateRules() throws {
        let subjects = getDatasetSubjects(try ProductionCommentDataset.loadBundled().data)

        XCTAssertTrue(subjectRequiresConcreteFocus("The Arts"))
        XCTAssertTrue(subjectRequiresConcreteFocus("Technologies"))
        XCTAssertFalse(subjectRequiresConcreteFocus("English"))
        XCTAssertEqual(getConcreteFocusOptions("technology"), ["Design and Technologies", "Digital Technologies", "Technologies"])
        XCTAssertTrue(subjectMatchesUiSubject(datasetSubject: "Digital Technologies", uiSubject: "Technologies", datasetSubjects: subjects))
        XCTAssertFalse(subjectMatchesUiSubject(datasetSubject: "Music", uiSubject: "Technologies", datasetSubjects: subjects))
    }
}
