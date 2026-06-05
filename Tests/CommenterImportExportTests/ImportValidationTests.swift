import CommenterDomain
import CommenterImportExport
import XCTest

final class ImportValidationTests: XCTestCase {
    func testRosterCSVImportValidatesCompleteFileBeforeReturningStudents() throws {
        let imported = try ImportValidation.parseRosterImportCSV(
            "First Name,Last Name,Year Level,Comments\nZoe,ONeil,Year 6,=@kept as text",
            existingRoster: roster,
            createID: { "new-id" }
        )

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].firstName, "Zoe")
        XCTAssertEqual(imported[0].lastName, "ONeil")
        XCTAssertEqual(imported[0].internalTeacherNote, "=@kept as text")

        let compact = try ImportValidation.parseRosterImportCSV(
            "FirstName,LastName,YearLevel,Gender,Attitude,Private Teacher Note\nMia,Chen,5,Female,Focused,Seat near reading group",
            existingRoster: [],
            createID: { "mia-id" }
        )
        XCTAssertEqual(compact[0].id, "mia-id")
        XCTAssertEqual(compact[0].yearLevel, .year5)
        XCTAssertEqual(compact[0].gender, .female)
        XCTAssertEqual(compact[0].attitudeDescriptor, "focused")
        XCTAssertEqual(compact[0].internalTeacherNote, "Seat near reading group")
    }

    func testRosterCSVImportBlocksDuplicatesAndUnsafeIDs() {
        XCTAssertThrowsError(try ImportValidation.parseRosterImportCSV(
            "First Name,Last Name,Year Level\nAva,Ng,Year 5",
            existingRoster: roster,
            createID: { "dup" }
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("already in the roster"))
        }

        XCTAssertThrowsError(try ImportValidation.parseRosterImportCSV(
            "First Name,Last Name,Year Level\nSam,Lee,Year 5\nSam,Lee,Year 5",
            existingRoster: [],
            createID: { "x" }
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("duplicate student"))
        }

        XCTAssertThrowsError(try ImportValidation.parseRosterImportCSV(
            "First Name,Last Name,Year Level\nBen,Stone,Year 5",
            existingRoster: roster,
            createID: { "s1" }
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("could not be prepared safely"))
        }
    }

    func testResultsCSVImportRequiresAggregateConcreteFocusAndCanonicalSubject() throws {
        let imported = try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,Focus,Evidence",
                "Ava,Ng,The Arts,At Standard,Music,kept rhythm",
                "Ava,Ng,Technologies,Developing,Digital Technologies,built an algorithm"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )

        XCTAssertEqual(imported.count, 2)
        XCTAssertEqual(imported[0].subject, "The Arts")
        XCTAssertEqual(imported[0].focusStrand, "Music")
        XCTAssertEqual(imported[1].subject, "Technologies")
        XCTAssertEqual(imported[1].focusStrand, "Digital Technologies")

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            "First Name,Last Name,Subject,Achievement Level,Focus\nAva,Ng,The Arts,At Standard,",
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("requires a specific subject in Focus"))
        }
    }

    func testResultsCSVImportResolvesDuplicateNamesOnlyWithMatchingYear() throws {
        let duplicateNameRoster = [
            Student(id: "s5", firstName: "Sam", lastName: "Lee", yearLevel: .year5),
            Student(id: "s6", firstName: "Sam", lastName: "Lee", yearLevel: .year6)
        ]

        let imported = try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Year Level,Subject,Achievement Level",
                "Sam,Lee,Year 6,English,At Standard"
            ].joined(separator: "\n"),
            roster: duplicateNameRoster,
            selectedSubjects: selectedSubjects
        )

        XCTAssertEqual(imported[0].studentId, "s6")

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level",
                "Sam,Lee,English,At Standard"
            ].joined(separator: "\n"),
            roster: duplicateNameRoster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("student name is ambiguous"))
        }
    }

    func testResultsCSVImportValidatesLibraryBackedOptionFields() throws {
        let imported = try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,English Focus Tags,Next Step Goals,Comments",
                "Ava,Ng,English,At Standard,\"inferencing, vocabulary\",\"vary sentence openings, use evidence from text\",Strong progress"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )

        XCTAssertEqual(imported[0].englishFocusTags, ["Inferencing", "Vocabulary"])
        XCTAssertEqual(imported[0].nextStepGoals, ["vary sentence openings", "use evidence from text"])
        XCTAssertEqual(imported[0].reportEmphasisNote, "Strong progress")
        XCTAssertEqual(imported[0].commentsText, "")

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,English Focus Tags",
                "Ava,Ng,English,At Standard,\"Inferencing, Vocabulary, Punctuation\""
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("English focus areas supports at most 2 values"))
        }
    }

    func testResultsCSVImportRejectsContextPlaceholdersAndUnreasonableLengths() {
        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,Text Type",
                "Ava,Ng,English,At Standard,[text type]"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("must not contain template placeholders"))
        }

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            "First Name,Last Name,Subject,Achievement Level,Evidence\nAva,Ng,English,At Standard,\(String(repeating: "x", count: 2_001))",
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Evidence must be 2000 characters or fewer"))
        }

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            "First Name,Last Name,Subject,Achievement Level,Comments\nAva,Ng,English,At Standard,\(String(repeating: "x", count: 181))",
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Optional report note must be 180 characters or fewer"))
        }
    }

    func testResultsCSVImportRejectsSentenceLikeContextFields() {
        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,Text Type",
                "Ava,Ng,English,At Standard,They created a persuasive paragraph"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Text type / genre must be a short phrase without leading pronouns"))
        }

        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,Learning Context",
                "Ava,Ng,English,At Standard,Ava solved multi-step problems"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Learning context / activity must be a short phrase, not a sentence"))
        }
    }

    func testResultsCSVImportBlocksPartialRowsWithoutReturningPartialImport() {
        XCTAssertThrowsError(try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level",
                "Ava,Ng,English,At Standard",
                "Ava,Ng,Mathematics,"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Import blocked"))
            XCTAssertTrue(error.localizedDescription.contains("row 3"))
        }
    }


    func testResultsCSVImportAcceptsFormalHealthAndPhysicalEducationLabel() throws {
        let imported = try ImportValidation.parseResultsImportCSV(
            [
                "First Name,Last Name,Subject,Achievement Level,Focus",
                "Ava,Ng,Health and Physical Education,At Standard,teamwork"
            ].joined(separator: "\n"),
            roster: roster,
            selectedSubjects: selectedSubjects.merging(["Health and P.E.": SelectedSubject(name: "Health and P.E.", allStrandsSelected: true)]) { current, _ in current }
        )

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(imported[0].subject, "Health and P.E.")
        XCTAssertEqual(displaySubjectName(imported[0].subject), "Health and Physical Education")
    }

    private var roster: [Student] {
        [Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)]
    }

    private var selectedSubjects: [String: SelectedSubject] {
        [
            "English": SelectedSubject(name: "English", allStrandsSelected: true),
            "Mathematics": SelectedSubject(name: "Mathematics", allStrandsSelected: true),
            "The Arts": SelectedSubject(name: "The Arts", allStrandsSelected: true),
            "Technologies": SelectedSubject(name: "Technologies", allStrandsSelected: true)
        ]
    }
}
