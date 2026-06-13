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
            AssembledVariant(variantID: "needs-context", keyID: "strength", text: "{StudentName} writes about [missing context].")
        ]
        var generator = try ReportGenerator(data: data, projectMetadata: metadata())
        let report = try generator.generateReport(student: student(), subject: "English", result: result(), generatedAt: 1)

        XCTAssertEqual(report.text, "Ava explains ideas in English. Ava uses evidence. Ava should revise punctuation.")
        XCTAssertEqual(report.variantIds, ["RECIPE_r1_1eade169"])
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

    func testZeroUsageEntriesDoNotBlockVariantSelection() throws {
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata(), existingUsage: ["v2": 0])
        let report = try generator.generateReport(student: student(), subject: "English", result: result(), generatedAt: 1)

        XCTAssertEqual(report.variantIds, ["v1"])
        XCTAssertEqual(generator.usageSnapshot(), ["v1": 1])
    }

    func testRepairsAndAppendsEvidenceWhenItIsNotSafeAsSpecificTask() throws {
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())
        var sourceResult = result()
        sourceResult.evidenceText = "used quotations"

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(report.text, "Ava writes clearly in English. Ava used quotations.")
        XCTAssertTrue((report.trace ?? "").contains("Rejected by placeholders/context"))
    }

    func testUsesSafeEvidencePhraseForSpecificTaskWithoutDuplicateAppend() throws {
        var data = fixtureData()
        data.assembledVariants = [
            AssembledVariant(variantID: "specific", keyID: "strength", text: "{StudentName} wrote a [text type] for [specific task].")
        ]
        var sourceResult = result()
        sourceResult.textType = "persuasive text"
        sourceResult.evidenceText = "advertising campaign"
        var generator = try ReportGenerator(data: data, projectMetadata: metadata())

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(report.text, "Ava wrote a persuasive text for advertising campaign.")
        XCTAssertEqual(report.variantIds, ["specific"])
        XCTAssertTrue((report.trace ?? "").contains("Teacher evidence was used through a safe specific task phrase."))
    }

    func testAddsReportContextSentenceWhenContextFieldsAreNotAlreadyConsumed() throws {
        var sourceResult = result()
        sourceResult.textType = "persuasive paragraph"
        sourceResult.learningContext = "class novel discussion"
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(report.text, "Ava writes clearly in English. This was demonstrated through persuasive paragraph in class novel discussion.")
        XCTAssertTrue((report.trace ?? "").contains("Teacher report context included."))
    }

    func testBlocksUnsafeReportContextFieldsBeforeGeneration() throws {
        var sourceResult = result()
        sourceResult.textType = "They wrote a persuasive paragraph"
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        XCTAssertThrowsError(try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Text type / genre starts like a sentence"))
        }
    }

    func testReportContextPunctuationIsNormalizedLikeV3() throws {
        var sourceResult = result()
        sourceResult.textType = "persuasive paragraph."
        sourceResult.learningContext = "class novel discussion."
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(report.text, "Ava writes clearly in English. This was demonstrated through persuasive paragraph in class novel discussion.")
    }

    func testAppendsRepairedReportNotesAndBlocksUnsafeNotes() throws {
        var sourceResult = result()
        sourceResult.reportEmphasisNote = "needs planning carefully"
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(
            student: student(reportEmphasisNote: "using feedback"),
            subject: "English",
            result: sourceResult,
            generatedAt: 1
        )

        XCTAssertEqual(report.text, "Ava writes clearly in English. Ava uses feedback. Ava would benefit from support with planning carefully.")
        XCTAssertTrue((report.trace ?? "").contains("Teacher/student note emphasis included."))

        sourceResult.reportEmphasisNote = "Keep [Student Name] placeholder."
        XCTAssertThrowsError(try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 2)) { error in
            XCTAssertTrue(error.localizedDescription.contains("template text"))
        }
    }

    func testAddsEnglishFocusAndReportFlagsDeterministically() throws {
        var sourceResult = result()
        sourceResult.englishFocusTags = ["Inferencing"]
        sourceResult.flags = [
            "TURN_TAKING_CALLING_OUT": true,
            "PARTICIPATION_ENGAGEMENT": true
        ]
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(student: student(gender: .female), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(
            report.text,
            "Ava writes clearly in English. In Inferencing, they demonstrate solid understanding. Ava is developing respectful discussion habits in English by waiting to be called on before speaking. Ava participates confidently in English and contributes thoughtful ideas during discussions."
        )
    }

    func testAddsMathProficiencyDispositionsAndNextStepLayout() throws {
        var sourceResult = AchievementResult(
            studentId: "s1",
            subject: "Mathematics",
            achievementLevel: .atStandard,
            focusStrand: "Number",
            mathProficiencies: ["Fluency"],
            mathMindsetToggles: ["Growth mindset", "Checks working carefully"],
            nextStepGoals: ["justify reasoning", "check working and show steps"]
        )
        sourceResult.evidenceText = nil
        var mathMetadata = metadata(subject: "Mathematics")
        mathMetadata.reportLayout = ReportLayout(
            enabled: true,
            order: [.general, .subject, .dispositions, .nextSteps],
            include: [.general: true, .subject: true, .dispositions: true, .nextSteps: true]
        )
        var generator = try ReportGenerator(data: mathData(), projectMetadata: mathMetadata)

        let report = try generator.generateReport(
            student: student(gender: .female, attitudeDescriptor: "diligent"),
            subject: "Mathematics",
            result: sourceResult,
            generatedAt: 1
        )

        XCTAssertEqual(
            report.text,
            [
                "Ava is a diligent learner who approaches Mathematics with enthusiasm.",
                "Ava solves problems in Mathematics. Ava shows solid skills in Fluency.",
                "Ava demonstrates a growth mindset and checks working carefully.",
                "To continue developing, Ava will focus on justify reasoning as well as check working and show steps."
            ].joined(separator: "\n\n")
        )
    }

    func testDisabledLayoutFlattensSelectedSectionsLikeV3() throws {
        var sourceMetadata = metadata()
        sourceMetadata.reportLayout = ReportLayout(enabled: false)
        var sourceResult = result()
        sourceResult.nextStepGoals = ["use evidence from text"]
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: sourceMetadata)

        let report = try generator.generateReport(student: student(attitudeDescriptor: "curious"), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(report.text, "A curious learner, Ava engages positively with English content. Ava writes clearly in English. A helpful next step for Ava is to use evidence from text.")
    }

    func testLayoutIncludeDefaultsKeepSubjectForcedLikeV3() throws {
        var sourceMetadata = metadata()
        sourceMetadata.reportLayout = ReportLayout(
            enabled: true,
            order: [.nextSteps, .subject],
            include: [.general: false, .subject: false]
        )
        var sourceResult = result()
        sourceResult.nextStepGoals = ["use evidence from text"]
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: sourceMetadata)

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(
            report.text,
            [
                "A helpful next step for Ava is to use evidence from text.",
                "Ava writes clearly in English."
            ].joined(separator: "\n\n")
        )
    }

    func testOptionalDecorationArraysIgnoreBlankValues() throws {
        var sourceResult = result()
        sourceResult.englishFocusTags = [" ", "Inferencing", ""]
        sourceResult.mathMindsetToggles = ["", "Growth mindset"]
        sourceResult.nextStepGoals = ["", "use evidence from text"]
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(student: student(gender: .female), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(
            report.text,
            [
                "Ava writes clearly in English. In Inferencing, they demonstrate solid understanding.",
                "Ava demonstrates a growth mindset.",
                "A helpful next step for Ava is to use evidence from text."
            ].joined(separator: "\n\n")
        )
    }

    func testDecorationArraysFallbackWhenExistingDataHasMoreThanTwoValues() throws {
        var sourceResult = result()
        sourceResult.englishFocusTags = ["Inferencing", "Vocabulary", "Punctuation"]
        sourceResult.nextStepGoals = ["use evidence from text", "edit for clarity", "vary sentence structure"]
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)

        XCTAssertEqual(
            report.text,
            [
                "Ava writes clearly in English. Ava has shown strength in Inferencing, Vocabulary, and Punctuation.",
                "Next steps for Ava include use evidence from text, edit for clarity, and vary sentence structure."
            ].joined(separator: "\n\n")
        )
    }

    func testUnsafeEvidenceTextBlocksGeneration() throws {
        var sourceResult = result()
        sourceResult.evidenceText = "Keep [context] placeholder."
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        XCTAssertThrowsError(try generator.generateReport(student: student(), subject: "English", result: sourceResult, generatedAt: 1)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Evidence could not be used safely"))
            XCTAssertTrue(error.localizedDescription.contains("template placeholders"))
        }
    }

    func testTeacherTextRepairAdjustsPronounVerbAgreement() throws {
        var sourceResult = result()
        sourceResult.reportEmphasisNote = "They use feedback and explain clearly"
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: metadata())

        let report = try generator.generateReport(
            student: student(gender: .female),
            subject: "English",
            result: sourceResult,
            generatedAt: 1
        )

        XCTAssertEqual(report.text, "Ava writes clearly in English. She uses feedback and explains clearly.")
    }

    func testTemplateHashMatchesV3UTF16SelectionForNonASCIIKeys() throws {
        var sourceMetadata = metadata(id: "p🙂")
        sourceMetadata.reportLayout = ReportLayout(enabled: true)
        var generator = try ReportGenerator(data: fixtureData(), projectMetadata: sourceMetadata)

        let report = try generator.generateReport(
            student: student(attitudeDescriptor: "curious"),
            subject: "English",
            result: result(),
            generatedAt: 1
        )

        XCTAssertEqual(
            report.text,
            "A curious learner, Ava engages positively with English content.\n\nAva writes clearly in English."
        )
    }

    func testGenerationFingerprintIgnoresProjectAdminMetadataAndNormalizesSourceContext() {
        var leftMetadata = metadata()
        leftMetadata.name = "Project A"
        leftMetadata.term = "Term 1"
        leftMetadata.yearLevel = .year5
        leftMetadata.selectedSubjects = [
            "Mathematics": SelectedSubject(name: "Mathematics", allStrandsSelected: true),
            "English": SelectedSubject(name: "English", allStrandsSelected: true)
        ]
        var rightMetadata = metadata()
        rightMetadata.name = "Project B"
        rightMetadata.term = "Term 2"
        rightMetadata.yearLevel = .year6
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
        XCTAssertFalse(left.contains("Project A"))
        XCTAssertFalse(left.contains("Term 1"))
        XCTAssertFalse(left.contains("selectedSubjectOrder"))
        XCTAssertFalse(left.contains("not applicable"))
        XCTAssertTrue(left.contains(#""learningContext":"advertising unit""#))
    }

    func testGenerationFingerprintMatchesV3JSONStringShape() {
        let fingerprint = buildGenerationFingerprint(
            projectMetadata: metadata(),
            student: student(),
            result: result(),
            concreteSubject: "English"
        )

        XCTAssertEqual(
            fingerprint,
            #"{"metadata":{"useFirstNameOnly":true,"reportLayout":{"enabled":true,"order":["general","subject","dispositions","nextSteps"],"include":{"general":true,"subject":true,"dispositions":true,"nextSteps":true}}},"student":{"id":"s1","firstName":"Ava","lastName":"Ng","gender":"","pronouns":"","yearLevel":"Year 5","reportEmphasisNote":"","attitudeDescriptor":""},"result":{"studentId":"s1","subject":"English","concreteSubject":"English","achievementLevel":"At Standard","focusStrand":"Writing","evidenceText":"","flags":{},"reportEmphasisNote":"","englishFocusTags":[],"mathProficiencies":[],"mathMindsetToggles":[],"nextStepGoals":[]}}"#
        )
    }

    func testGenerationFingerprintForcesSubjectLayoutFlagLikeV3() {
        var sourceMetadata = metadata()
        sourceMetadata.reportLayout = ReportLayout(
            enabled: true,
            order: [.nextSteps],
            include: [.subject: false]
        )

        let fingerprint = buildGenerationFingerprint(
            projectMetadata: sourceMetadata,
            student: student(),
            result: result(),
            concreteSubject: "English"
        )

        XCTAssertTrue(fingerprint.contains(#""order":["nextSteps","general","subject","dispositions"]"#))
        XCTAssertTrue(fingerprint.contains(#""subject":true"#))
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

    private func mathData() -> CommentEngineData {
        CommentEngineData(
            componentBank: [
                Component(keyID: "math-strength", subject: "Mathematics", type: .strength, level: "Year 5", band: "At Standard", text: "{StudentName} solves problems in {Subject}.", strand: "Number")
            ],
            recipeBank: [Recipe(recipeID: "r1", pattern: "{Strength}")],
            assembledVariants: [
                AssembledVariant(variantID: "math-v1", keyID: "math-strength", text: "{StudentName} solves problems in {Subject}.")
            ],
            uniquenessGuard: [UniquenessGuard(rule: "MaxUsagePerClass", value: 2)]
        )
    }

    private func metadata(id: String = "p1", subject: String = "English") -> ProjectMetadata {
        ProjectMetadata(
            id: id,
            name: "Project",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 1,
            updatedAt: 1,
            selectedSubjects: [subject: SelectedSubject(name: subject, allStrandsSelected: true)],
            useFirstNameOnly: true
        )
    }

    private func student(gender: Gender? = nil, reportEmphasisNote: String? = nil, attitudeDescriptor: String? = nil) -> Student {
        Student(
            id: "s1",
            firstName: "Ava",
            lastName: "Ng",
            gender: gender,
            yearLevel: .year5,
            reportEmphasisNote: reportEmphasisNote,
            attitudeDescriptor: attitudeDescriptor
        )
    }

    private func result() -> AchievementResult {
        AchievementResult(studentId: "s1", subject: "English", achievementLevel: .atStandard, focusStrand: "Writing")
    }

    private func artsResult(focus: String?) -> AchievementResult {
        AchievementResult(studentId: "s1", subject: "The Arts", achievementLevel: .atStandard, focusStrand: focus)
    }
}
