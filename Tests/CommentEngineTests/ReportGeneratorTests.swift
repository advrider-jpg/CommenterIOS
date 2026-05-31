import CommentEngine
import CommenterDomain
import XCTest

final class ReportGeneratorTests: XCTestCase {
    func testGeneratesDeterministicVariantReportAndRecordsUsage() throws {
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())
        let report = try generator.generateReport(
            student: student(),
            subject: "English",
            result: result(),
            generatedAt: 12_345
        )

        XCTAssertEqual(report.text, "Ava writes clearly in English.")
        XCTAssertEqual(report.variantIds, ["v1"])
        XCTAssertEqual(report.generatedAt, 12_345)
        XCTAssertEqual(report.resultFingerprint, buildGenerationFingerprint(projectMetadata: metadata(), student: student(), result: result(), concreteSubject: "English"))
        XCTAssertEqual(generator.usageSnapshot()["v1"], 1)
    }

    func testBlocksMissingAchievementLevel() throws {
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())
        var missingLevel = result()
        missingLevel.achievementLevel = nil

        XCTAssertThrowsError(try generator.generateReport(student: student(), subject: "English", result: missingLevel, generatedAt: 1)) { error in
            XCTAssertEqual(error as? ReportGenerationError, .missingAchievementLevel(studentName: "Ava", subject: "English"))
        }
    }

    func testAssemblesFromComponentsWhenVariantsCannotResolveContext() throws {
        var data = fixtureData()
        data.assembledVariants = [
            AssembledVariant(variantID: "needs-context", keyID: "strength", text: "{StudentName} writes about [unit/topic].")
        ]
        var generator = try ReportGenerator(data: data, projectMetadata: metadata())
        let report = try generator.generateReport(student: student(), subject: "English", result: result(), generatedAt: 1)

        XCTAssertEqual(report.text, "Ava writes clearly in English. Ava uses evidence. Ava should revise punctuation.")
        XCTAssertEqual(report.variantIds, ["ASSEMBLED_fd91849e"])
    }

    func testAggregateSubjectRequiresConcreteFocus() throws {
        var generator = try ReportGenerator(data: artsData(), projectMetadata: metadata())
        XCTAssertThrowsError(try generator.generateReport(student: student(), subject: "The Arts", result: artsResult(focus: nil), generatedAt: 1)) { error in
            guard case let .unavailableSubject(message) = error as? ReportGenerationError else {
                return XCTFail("Expected unavailable subject")
            }
            XCTAssertTrue(message.contains("needs the specific subject chosen"))
        }
    }

    func testAggregateSubjectUsesConcreteFocus() throws {
        var generator = try ReportGenerator(data: artsData(), projectMetadata: metadata())
        let report = try generator.generateReport(student: student(), subject: "The Arts", result: artsResult(focus: "Drama"), generatedAt: 1)

        XCTAssertEqual(report.concreteSubject, "Drama")
        XCTAssertEqual(report.text, "Ava performs confidently in Drama.")
    }

    func testUniquenessBlocksRecentlyUsedAdjacentVariant() throws {
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata(), usedVariantIds: ["v1"], existingUsage: ["v1": 1])
        let report = try generator.generateReport(student: student(), subject: "English", result: result(), generatedAt: 1)

        XCTAssertEqual(report.variantIds, ["v3"])
        XCTAssertEqual(report.text, "Ava explains ideas in English.")
    }

    func testGenerationFingerprintUsesStableSubjectOrderAndSourceContextNormalization() {
        var leftMetadata = metadata()
        leftMetadata.selectedSubjects = [
            "Mathematics": SelectedSubject(name: "Mathematics", allStrandsSelected: true),
            "English": SelectedSubject(name: "English", allStrandsSelected: true)
        ]
        var rightMetadata = metadata()
        rightMetadata.selectedSubjects = [
            "English": SelectedSubject(name: "English", allStrandsSelected: true),
            "Mathematics": SelectedSubject(name: "Mathematics", allStrandsSelected: true)
        ]
        var sourceResult = result()
        sourceResult.textType = "not applicable"
        sourceResult.learningContext = "advertising unit."

        let left = buildGenerationFingerprint(projectMetadata: leftMetadata, student: student(), result: sourceResult, concreteSubject: "English")
        let right = buildGenerationFingerprint(projectMetadata: rightMetadata, student: student(), result: sourceResult, concreteSubject: "English")

        XCTAssertEqual(left, right)
        XCTAssertTrue(left.contains(#""selectedSubjectOrder":["English","Mathematics"]"#))
        XCTAssertFalse(left.contains("not applicable"))
        XCTAssertTrue(left.contains(#""learningContext":"advertising unit""#))
    }

    private func fixtureData() -> CommentEngineData {
        CommentEngineData(
            componentBank: [
                Component(keyID: "strength", subject: "English", type: .strength, level: "Year 5", band: "At Standard", text: "{StudentName} writes clearly in {Subject}", strand: "Writing"),
                Component(keyID: "evidence", subject: "English", type: .evidence, level: "Year 5", band: "At Standard", text: "{StudentName} uses evidence", strand: "Writing"),
                Component(keyID: "next", subject: "English", type: .nextStep, level: "Year 5", band: "At Standard", text: "{StudentName} should revise punctuation", strand: "Writing"),
                Component(keyID: "alt", subject: "English", type: .strength, level: "Year 5", band: "At Standard", text: "{StudentName} explains ideas in {Subject}", strand: "Writing")
            ],
            recipeBank: [Recipe(recipeID: "r1", pattern: "{Strength} {Evidence} {NextStep}")],
            assembledVariants: [
                AssembledVariant(variantID: "v1", keyID: "strength", text: "{StudentName} writes clearly in {Subject}."),
                AssembledVariant(variantID: "v2", keyID: "evidence", text: "{StudentName} uses evidence in {Subject}."),
                AssembledVariant(variantID: "v3", keyID: "alt", text: "{StudentName} explains ideas in {Subject}.")
            ],
            uniquenessGuard: [
                UniquenessGuard(rule: "MaxUsagePerClass", value: 2),
                UniquenessGuard(rule: "MinVariantDistance", value: 2)
            ]
        )
    }

    private func artsData() -> CommentEngineData {
        CommentEngineData(
            componentBank: [
                Component(keyID: "drama", subject: "Drama", type: .strength, level: "Year 5", band: "At Standard", text: "{StudentName} performs confidently in {Subject}."),
                Component(keyID: "music", subject: "Music", type: .strength, level: "Year 5", band: "At Standard", text: "{StudentName} performs confidently in {Subject}.")
            ],
            recipeBank: [Recipe(recipeID: "r1", pattern: "{Strength}")],
            assembledVariants: [
                AssembledVariant(variantID: "drama-v", keyID: "drama", text: "{StudentName} performs confidently in {Subject}."),
                AssembledVariant(variantID: "music-v", keyID: "music", text: "{StudentName} performs confidently in {Subject}.")
            ],
            uniquenessGuard: [UniquenessGuard(rule: "MaxUsagePerClass", value: 2)]
        )
    }

    private func metadata() -> ProjectMetadata {
        ProjectMetadata(
            id: "p1",
            name: "Project",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 1,
            updatedAt: 1,
            selectedSubjects: ["English": SelectedSubject(name: "English", allStrandsSelected: true)],
            useFirstNameOnly: true
        )
    }

    private func student() -> Student {
        Student(id: "s1", firstName: "Ava", lastName: "Ng", yearLevel: .year5)
    }

    private func result() -> AchievementResult {
        AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Writing")
    }

    private func artsResult(focus: String?) -> AchievementResult {
        AchievementResult(studentId: "s1", subject: "The Arts", achievementLevel: .atStandard, focusStrand: focus)
    }
}
