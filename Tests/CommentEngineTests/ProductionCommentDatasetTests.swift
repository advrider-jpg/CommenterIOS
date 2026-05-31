import CommentEngine
import CommenterDomain
import XCTest

final class ProductionCommentDatasetTests: XCTestCase {
    func testBundledProductionDatasetLoadsAndValidates() throws {
        let engine = try ProductionCommentDataset.loadBundled()

        XCTAssertTrue(engine.diagnostics.valid)
        XCTAssertEqual(engine.diagnostics.componentCount, 56_564)
        XCTAssertEqual(engine.diagnostics.recipeCount, 5)
        XCTAssertEqual(engine.diagnostics.assembledVariantCount, 4_340)
        XCTAssertEqual(engine.diagnostics.uniquenessGuardCount, 2)
        XCTAssertTrue(engine.diagnostics.subjects.contains("Health and P.E."))
        XCTAssertEqual(engine.diagnostics.uniquenessRules["MaxUsagePerClass"], 3)
        XCTAssertEqual(engine.diagnostics.uniquenessRules["MinVariantDistance"], 5)
        XCTAssertGreaterThan(engine.diagnostics.placeholderCounts["[Student Name]"] ?? 0, 0)
        XCTAssertFalse(engine.diagnostics.datasetHash.isEmpty)
        XCTAssertEqual(engine.diagnostics.normalizedSourceHash, "438950a8a72de0ce3b6b0e4271f95858d6519162c9f530a295e36722618b9572")
    }

    func testDatasetDiagnosticsRejectMalformedRecordsWithoutPromotingThemToEligibleData() throws {
        let raw = """
        {
          "ComponentBank": {
            "valid": { "Key_ID": "c1", "Subject": "English", "Type": "Strength", "Level": "Year 5", "Band": "At Standard", "Text": "[Student Name] writes." },
            "duplicate": { "Key_ID": "c1", "Subject": "English", "Type": "Strength", "Level": "Year 5", "Band": "At Standard", "Text": "Duplicate key text." },
            "missing": { "Key_ID": "missing-text", "Subject": "English", "Type": "Strength", "Level": "Year 5", "Band": "At Standard" },
            "unsupported": { "Key_ID": "bad-type", "Subject": "English", "Type": "Summary", "Level": "Year 5", "Band": "At Standard", "Text": "Unsupported." },
            "malformed": ["not a record"]
          },
          "RecipeBank": {
            "valid": { "Recipe_ID": "r1", "Pattern": "{Strength}. {NextStep}." },
            "missing": { "Recipe_ID": "r2" },
            "malformed": "not a record"
          },
          "AssembledVariants": {
            "valid": { "Variant_ID": "v1", "Key_ID": "c1", "Text": "[Student Name] writes." },
            "duplicate": { "Variant_ID": "v1", "Key_ID": "c1", "Text": "Duplicate variant text." },
            "orphan": { "Variant_ID": "orphan", "Key_ID": "missing-component", "Text": "Orphan." },
            "missing": { "Variant_ID": "missing-text", "Key_ID": "c1" },
            "malformed": 4
          },
          "UniquenessGuard": {
            "valid": { "Rule": "MaxUsagePerClass", "Value": "2" },
            "missing": { "Rule": "MinVariantDistance" },
            "badValue": { "Rule": "BadValue", "Value": "not numeric" },
            "malformed": false
          }
        }
        """

        let validation = try ProductionCommentDataset.diagnose(rawData: Data(raw.utf8))

        XCTAssertTrue(validation.diagnostics.valid)
        XCTAssertEqual(validation.diagnostics.componentCount, 2)
        XCTAssertEqual(validation.diagnostics.recipeCount, 1)
        XCTAssertEqual(validation.diagnostics.assembledVariantCount, 2)
        XCTAssertEqual(validation.diagnostics.uniquenessGuardCount, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.componentBank]?.malformed, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.componentBank]?.missingRequiredFields, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.componentBank]?.unsupportedType, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.recipeBank]?.malformed, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.recipeBank]?.missingRequiredFields, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.assembledVariants]?.malformed, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.assembledVariants]?.missingRequiredFields, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.assembledVariants]?.orphaned, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.uniquenessGuard]?.malformed, 1)
        XCTAssertEqual(validation.diagnostics.rejected[.uniquenessGuard]?.missingRequiredFields, 2)
        XCTAssertEqual(validation.diagnostics.uniquenessRules, ["MaxUsagePerClass": 2])
        XCTAssertEqual(validation.diagnostics.placeholderCounts["[Student Name]"], 2)
        XCTAssertTrue(validation.diagnostics.warnings.contains { $0.contains("ComponentBank was supplied as an object") })
        XCTAssertTrue(validation.diagnostics.warnings.contains { $0.contains("Duplicate ComponentBank Key_ID") })
        XCTAssertTrue(validation.diagnostics.warnings.contains { $0.contains("Duplicate AssembledVariants Variant_ID") })
    }

    func testDatasetDiagnosticsTreatMissingComponentsAndRecipesAsFatalButEmptyGuardsAsWarnings() throws {
        let raw = """
        {
          "ComponentBank": [],
          "RecipeBank": [],
          "AssembledVariants": [],
          "UniquenessGuard": []
        }
        """

        let validation = try ProductionCommentDataset.diagnose(rawData: Data(raw.utf8))

        XCTAssertFalse(validation.diagnostics.valid)
        XCTAssertTrue(validation.diagnostics.errors.contains("ComponentBank has no eligible records."))
        XCTAssertTrue(validation.diagnostics.errors.contains("RecipeBank has no eligible records."))
        XCTAssertTrue(validation.diagnostics.warnings.contains { $0.contains("AssembledVariants has no eligible records") })
        XCTAssertTrue(validation.diagnostics.warnings.contains { $0.contains("UniquenessGuard has no eligible records") })
    }

    func testPlaceholderResolutionRequiresRealContext() {
        let metadata = ProjectMetadata(
            id: "project-1",
            name: "Room 1",
            term: "Term 1",
            yearLevel: .year5,
            createdAt: 0,
            updatedAt: 0,
            useFirstNameOnly: true
        )
        let student = Student(id: "student-1", firstName: "Ada", lastName: "Lovelace", gender: .female, yearLevel: .year5)
        let result = AchievementResult(
            studentId: student.id,
            subject: "English",
            achievementLevel: .atStandard,
            focusStrand: "Reading",
            evidenceText: "inferring character motivation"
        )
        let context = buildPlaceholderContext(student: student, subject: "English", result: result, projectMetadata: metadata)

        let resolved = resolveReportPlaceholders(
            text: "[Student name] used [specific task] in {Subject}. [He/She] explained ideas clearly.",
            context: context
        )

        XCTAssertEqual(resolved.text, "Ada used inferring character motivation in English. She explained ideas clearly.")
        XCTAssertTrue(resolved.unresolved.isEmpty)
        XCTAssertTrue(resolved.missingContext.isEmpty)
    }
}
