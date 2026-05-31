import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

public enum ProductionCommentDatasetError: LocalizedError, Equatable {
    case missingBundledDataset
    case invalidDataset(String)

    public var errorDescription: String? {
        switch self {
        case .missingBundledDataset:
            return "The bundled production comment-engine dataset is missing."
        case let .invalidDataset(message):
            return message
        }
    }
}

public enum ProductionCommentDataset {
    public static let resourceName = "comment-engine"
    public static let resourceExtension = "json"

    private static let requiredComponentFields = ["Key_ID", "Subject", "Type", "Level", "Band", "Text"]
    private static let requiredVariantFields = ["Variant_ID", "Key_ID", "Text"]
    private static let requiredRecipeFields = ["Recipe_ID", "Pattern"]
    private static let requiredGuardFields = ["Rule", "Value"]
    private static let supportedComponentTypes: Set<String> = ["Strength", "Evidence", "NextStep"]
    private static let bracketPlaceholderPattern = #"\[[^\]]+\]"#

    public static func loadBundled() throws -> ValidatedCommentEngine {
        guard let url = Bundle.module.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw ProductionCommentDatasetError.missingBundledDataset
        }
        let data = try Data(contentsOf: url)
        return try validate(rawData: data)
    }

    public static func validate(rawData: Data) throws -> ValidatedCommentEngine {
        let validation = try diagnose(rawData: rawData)
        guard validation.diagnostics.valid else {
            throw ProductionCommentDatasetError.invalidDataset(validation.diagnostics.errors.joined(separator: " "))
        }
        return validation
    }

    public static func diagnose(rawData: Data) throws -> ValidatedCommentEngine {
        let root: [String: Any]
        do {
            let json = try JSONSerialization.jsonObject(with: rawData)
            guard let record = json as? [String: Any] else {
                return invalidRoot(rawData: rawData, message: "Comment engine data is not a JSON object.")
            }
            root = record
        } catch {
            throw ProductionCommentDatasetError.invalidDataset("Comment engine data could not be decoded: \(error.localizedDescription)")
        }

        var errors: [String] = []
        var warnings: [String] = []
        var rejected = CommentEngineSection.defaultRejections
        var placeholderCounts: [String: Int] = [:]

        let rawComponents = values(for: root["ComponentBank"], section: .componentBank, errors: &errors, warnings: &warnings)
        let rawRecipes = values(for: root["RecipeBank"], section: .recipeBank, errors: &errors, warnings: &warnings)
        let rawVariants = values(for: root["AssembledVariants"], section: .assembledVariants, errors: &errors, warnings: &warnings)
        let rawGuards = values(for: root["UniquenessGuard"], section: .uniquenessGuard, errors: &errors, warnings: &warnings)

        var components: [Component] = []
        var componentIds = Set<String>()

        rawComponents.forEach { entry in
            guard let record = entry as? [String: Any] else {
                rejected[.componentBank, default: RejectionCount(unsupportedType: 0)].malformed += 1
                return
            }
            guard hasRequiredStrings(record, fields: requiredComponentFields) else {
                rejected[.componentBank, default: RejectionCount(unsupportedType: 0)].missingRequiredFields += 1
                return
            }
            let type = requiredString(record, field: "Type") ?? ""
            guard supportedComponentTypes.contains(type),
                  let componentType = Component.ComponentType(rawValue: type)
            else {
                var count = rejected[.componentBank, default: RejectionCount(unsupportedType: 0)]
                count.unsupportedType = (count.unsupportedType ?? 0) + 1
                rejected[.componentBank] = count
                return
            }

            let component = Component(
                keyID: requiredString(record, field: "Key_ID") ?? "",
                subject: requiredString(record, field: "Subject") ?? "",
                type: componentType,
                level: requiredString(record, field: "Level") ?? "",
                band: requiredString(record, field: "Band") ?? "",
                text: requiredString(record, field: "Text") ?? "",
                strand: requiredString(record, field: "Strand")
            )
            if componentIds.contains(component.keyID) {
                warnings.append("Duplicate ComponentBank Key_ID encountered: \(component.keyID). The first eligible record remains indexed by the generator.")
            }
            componentIds.insert(component.keyID)
            incrementPlaceholderCounts(component.text, counts: &placeholderCounts)
            components.append(component)
        }

        let recipes: [Recipe] = rawRecipes.compactMap { entry in
            guard let record = entry as? [String: Any] else {
                rejected[.recipeBank, default: RejectionCount()].malformed += 1
                return nil
            }
            guard hasRequiredStrings(record, fields: requiredRecipeFields) else {
                rejected[.recipeBank, default: RejectionCount()].missingRequiredFields += 1
                return nil
            }
            return Recipe(
                recipeID: requiredString(record, field: "Recipe_ID") ?? "",
                pattern: requiredString(record, field: "Pattern") ?? ""
            )
        }

        var variants: [AssembledVariant] = []
        var variantIds = Set<String>()
        rawVariants.forEach { entry in
            guard let record = entry as? [String: Any] else {
                rejected[.assembledVariants, default: RejectionCount(orphaned: 0)].malformed += 1
                return
            }
            guard hasRequiredStrings(record, fields: requiredVariantFields) else {
                rejected[.assembledVariants, default: RejectionCount(orphaned: 0)].missingRequiredFields += 1
                return
            }
            let keyID = requiredString(record, field: "Key_ID") ?? ""
            guard componentIds.contains(keyID) else {
                var count = rejected[.assembledVariants, default: RejectionCount(orphaned: 0)]
                count.orphaned = (count.orphaned ?? 0) + 1
                rejected[.assembledVariants] = count
                return
            }
            let variant = AssembledVariant(
                variantID: requiredString(record, field: "Variant_ID") ?? "",
                keyID: keyID,
                text: requiredString(record, field: "Text") ?? ""
            )
            if variantIds.contains(variant.variantID) {
                warnings.append("Duplicate AssembledVariants Variant_ID encountered: \(variant.variantID).")
            }
            variantIds.insert(variant.variantID)
            incrementPlaceholderCounts(variant.text, counts: &placeholderCounts)
            variants.append(variant)
        }

        var uniquenessRules: [String: Double] = [:]
        let guards: [UniquenessGuard] = rawGuards.compactMap { entry in
            guard let record = entry as? [String: Any] else {
                rejected[.uniquenessGuard, default: RejectionCount()].malformed += 1
                return nil
            }
            guard hasRequiredStrings(record, fields: requiredGuardFields), let value = numericValue(record["Value"]), value.isFinite else {
                rejected[.uniquenessGuard, default: RejectionCount()].missingRequiredFields += 1
                return nil
            }
            let guardRule = UniquenessGuard(rule: requiredString(record, field: "Rule") ?? "", value: value)
            uniquenessRules[guardRule.rule] = guardRule.value
            return guardRule
        }

        if components.isEmpty {
            errors.append("ComponentBank has no eligible records.")
        }
        if recipes.isEmpty {
            errors.append("RecipeBank has no eligible records.")
        }
        if variants.isEmpty {
            warnings.append("AssembledVariants has no eligible records; generation can only use component assembly.")
        }
        if guards.isEmpty {
            warnings.append("UniquenessGuard has no eligible records; repetition controls will use safe defaults.")
        }

        let data = CommentEngineData(
            componentBank: components,
            recipeBank: recipes,
            assembledVariants: variants,
            uniquenessGuard: guards
        )
        let diagnostics = CommentEngineDiagnostics(
            valid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            componentCount: components.count,
            recipeCount: recipes.count,
            assembledVariantCount: variants.count,
            uniquenessGuardCount: guards.count,
            subjects: uniqueSorted(components.map(\.subject)),
            bands: uniqueSorted(components.map(\.band)),
            levels: uniqueSorted(components.map(\.level)),
            rejected: rejected,
            uniquenessRules: uniquenessRules,
            placeholderCounts: placeholderCounts,
            datasetHash: datasetHash(rawData),
            normalizedSourceHash: normalizedDatasetHash(rawData)
        )

        return ValidatedCommentEngine(data: data, diagnostics: diagnostics)
    }

    public static func diagnosticSummary(_ diagnostics: CommentEngineDiagnostics) -> String {
        let status = diagnostics.valid ? "valid" : "invalid"
        let base = "Comment engine data is \(status). Eligible records: \(diagnostics.componentCount) components, \(diagnostics.recipeCount) recipes, \(diagnostics.assembledVariantCount) assembled variants, \(diagnostics.uniquenessGuardCount) uniqueness rules."
        let errors = diagnostics.errors.isEmpty ? "" : " Errors: \(diagnostics.errors.joined(separator: " "))"
        let warnings = diagnostics.warnings.isEmpty ? "" : " Warnings: \(diagnostics.warnings.joined(separator: " "))"
        return base + errors + warnings
    }

    private static func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values.filter { !$0.isEmpty })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func invalidRoot(rawData: Data, message: String) -> ValidatedCommentEngine {
        let diagnostics = CommentEngineDiagnostics(
            valid: false,
            errors: [message],
            warnings: [],
            componentCount: 0,
            recipeCount: 0,
            assembledVariantCount: 0,
            uniquenessGuardCount: 0,
            subjects: [],
            bands: [],
            levels: [],
            rejected: CommentEngineSection.defaultRejections,
            uniquenessRules: [:],
            placeholderCounts: [:],
            datasetHash: datasetHash(rawData),
            normalizedSourceHash: normalizedDatasetHash(rawData)
        )
        return ValidatedCommentEngine(
            data: CommentEngineData(componentBank: [], recipeBank: [], assembledVariants: [], uniquenessGuard: []),
            diagnostics: diagnostics
        )
    }

    private static func values(
        for value: Any?,
        section: CommentEngineSection,
        errors: inout [String],
        warnings: inout [String]
    ) -> [Any] {
        if let array = value as? [Any] {
            return array
        }
        if let record = value as? [String: Any] {
            warnings.append("\(section.rawValue) was supplied as an object; using its values as records.")
            return Array(record.values)
        }
        errors.append("\(section.rawValue) is missing or is not an array/object.")
        return []
    }

    private static func requiredString(_ record: [String: Any], field: String) -> String? {
        guard let value = record[field], !(value is NSNull) else { return nil }
        let rendered = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return rendered.isEmpty ? nil : rendered
    }

    private static func hasRequiredStrings(_ record: [String: Any], fields: [String]) -> Bool {
        fields.allSatisfy { requiredString(record, field: $0) != nil }
    }

    private static func numericValue(_ value: Any?) -> Double? {
        if let number = value as? NSNumber {
            return number.doubleValue
        }
        if let string = value as? String {
            return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    private static func incrementPlaceholderCounts(_ text: String, counts: inout [String: Int]) {
        guard let regex = try? NSRegularExpression(pattern: bracketPlaceholderPattern) else { return }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        regex.matches(in: text, range: range).forEach { match in
            guard let matchRange = Range(match.range, in: text) else { return }
            let placeholder = String(text[matchRange])
            counts[placeholder, default: 0] += 1
        }
    }

    private static func datasetHash(_ data: Data) -> String {
        sha256Hex(data)
    }

    private static func normalizedDatasetHash(_ data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return datasetHash(data)
        }
        return sha256Hex(Data(text.replacingOccurrences(of: "\r\n", with: "\n").utf8))
    }

    private static func sha256Hex(_ data: Data) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
        #endif
    }
}
