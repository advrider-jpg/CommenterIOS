import Foundation

typealias RecipeComponentType = Component.ComponentType

enum RecipeComponentMode: String, Equatable, Sendable {
    case sentenceComponents = "sentence-components"
    case phraseComponents = "phrase-components"
}

struct RenderedRecipeSlot: Equatable, Sendable {
    var type: RecipeComponentType
    var component: Component
    var renderedText: String
}

struct RecipeRenderResult: Equatable, Sendable {
    var ok: Bool
    var text: String
    var recipeID: String
    var sourceRecipeID: String
    var componentIDs: [String]
    var missingSlots: [RecipeComponentType]
    var unresolved: [String]
    var errors: [String]
}

private struct RecipeCompileResult {
    var ok: Bool
    var recipeID: String
    var componentMode: RecipeComponentMode
    var componentSlots: [RecipeComponentType]
    var requiredTypes: [RecipeComponentType]
    var unknownSlots: [String]
    var unsafeSentenceComponentFrames: [String]
    var errors: [String]
}

private let componentSlotOrder: [RecipeComponentType] = [.strength, .evidence, .nextStep]
private let supportedRecipeSlots: Set<String> = [
    "Strength",
    "Evidence",
    "NextStep",
    "Name",
    "StudentName",
    "Subject",
    "subject",
    "HeShe",
    "heshe",
    "HimHer",
    "himher",
    "HisHer",
    "hisher"
]

func renderRecipe(recipe: Recipe, slots: [RecipeComponentType: RenderedRecipeSlot], context: PlaceholderContext) -> RecipeRenderResult {
    let compiled = compileRecipe(recipe)
    let missingSlots = compiled.requiredTypes.filter { slots[$0] == nil }
    let componentIDs = compiled.requiredTypes.compactMap { slots[$0]?.component.keyID }
    let syntheticID = recipeSyntheticVariantID(recipeID: compiled.recipeID.isEmpty ? recipe.recipeID : compiled.recipeID, componentIDs: componentIDs)
    var errors = compiled.errors
    var unresolved = Set<String>()
    var renderedComponentText: [RecipeComponentType: String] = [:]

    missingSlots.forEach { errors.append("Missing required component slot \"\($0.rawValue)\".") }

    compiled.requiredTypes.forEach { type in
        guard let slot = slots[type] else { return }
        if slot.type != type || slot.component.type != type {
            errors.append("Slot \"\(type.rawValue)\" was provided with a \(slot.type.rawValue) component.")
            return
        }
        let text = cleanSpacing(slot.renderedText)
        if text.isEmpty {
            errors.append("Slot \"\(type.rawValue)\" rendered empty text.")
            return
        }
        findUnresolvedPlaceholders(text).forEach { unresolved.insert($0) }
        if compiled.componentMode == .phraseComponents, looksSentenceLike(text, context: context) {
            errors.append("Slot \"\(type.rawValue)\" is sentence-shaped but recipe \(compiled.recipeID) expects phrase components.")
            return
        }
        renderedComponentText[type] = compiled.componentMode == .sentenceComponents ? ensureSentence(text) : text
    }

    if !unresolved.isEmpty {
        errors.append("Component slot text contains unresolved placeholders: \(Array(unresolved).sorted().joined(separator: ", ")).")
    }

    if !errors.isEmpty {
        return RecipeRenderResult(
            ok: false,
            text: "",
            recipeID: syntheticID,
            sourceRecipeID: compiled.recipeID,
            componentIDs: componentIDs,
            missingSlots: missingSlots,
            unresolved: Array(unresolved).sorted(),
            errors: errors
        )
    }

    let rendered = normalizeRecipeText(replaceRecipeSlots(in: recipe.pattern, componentText: renderedComponentText, context: context))
    findUnresolvedPlaceholders(rendered).forEach { unresolved.insert($0) }
    if let duplicate = duplicateDisplayName(rendered, displayName: context.displayName) {
        errors.append("Rendered recipe repeats the student name: \"\(duplicate)\".")
    }
    if rendered.isEmpty {
        errors.append("Recipe \(compiled.recipeID) rendered empty text.")
    }
    if !unresolved.isEmpty {
        errors.append("Rendered recipe contains unresolved placeholders: \(Array(unresolved).sorted().joined(separator: ", ")).")
    }
    if let languageIssue = firstBlockingLanguageIssue(lintReportLanguage(
        rendered,
        displayName: context.displayName,
        firstName: firstName(from: context),
        expectedSubjectPronoun: context.heShe
    )) {
        errors.append("Rendered recipe has a blocking language issue (\(languageIssue.code)).")
    }

    return RecipeRenderResult(
        ok: errors.isEmpty,
        text: errors.isEmpty ? rendered : "",
        recipeID: syntheticID,
        sourceRecipeID: compiled.recipeID,
        componentIDs: componentIDs,
        missingSlots: missingSlots,
        unresolved: Array(unresolved).sorted(),
        errors: errors
    )
}

func recipeSyntheticVariantID(recipeID: String, componentIDs: [String]) -> String {
    let safeRecipeID = cleanSpacing(recipeID)
        .replacingOccurrences(of: #"[^A-Za-z0-9_-]+"#, with: "_", options: .regularExpression)
        .ifEmpty("UNKNOWN")
    let key = "\(safeRecipeID)|\(componentIDs.joined(separator: "|"))"
    return "RECIPE_\(safeRecipeID)_\(String(format: "%08x", fnv1aRecipeHash(key)))"
}

private func compileRecipe(_ recipe: Recipe) -> RecipeCompileResult {
    let recipeID = recipe.recipeID.trimmingCharacters(in: .whitespacesAndNewlines)
    let pattern = recipe.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
    let componentMode = recipeComponentMode(recipe)
    let slots = extractSlots(pattern)
    let unknownSlots = uniqueInOrder(slots.filter { !supportedRecipeSlots.contains($0) })
    let componentSlots = uniqueInOrder(slots.compactMap(componentType))
    let unsafeFrames = componentMode == .sentenceComponents ? uniqueInOrder(sentenceComponentFrames(pattern)) : []
    let declaredTypes = recipe.requiredTypes
    let requiredTypes = declaredTypes.map(uniqueInOrder) ?? componentSlots
    var errors: [String] = []

    if recipeID.isEmpty { errors.append("Recipe_ID is required.") }
    if pattern.isEmpty { errors.append("Pattern is required.") }
    if let mode = recipe.componentMode,
       mode != RecipeComponentMode.sentenceComponents.rawValue,
       mode != RecipeComponentMode.phraseComponents.rawValue {
        errors.append("Unsupported ComponentMode \"\(mode)\".")
    }
    unknownSlots.forEach { errors.append("Unsupported recipe slot \"{\($0)}\".") }
    unsafeFrames.forEach { errors.append("Sentence component slot is embedded in unsafe recipe frame \"\($0)\".") }
    if declaredTypes != nil {
        let missingFromDeclaration = componentSlots.filter { !requiredTypes.contains($0) }
        let unusedDeclaration = requiredTypes.filter { !componentSlots.contains($0) }
        missingFromDeclaration.forEach { errors.append("RequiredTypes is missing component slot \"\($0.rawValue)\".") }
        unusedDeclaration.forEach { errors.append("RequiredTypes includes \"\($0.rawValue)\" but the pattern does not use it.") }
    }

    return RecipeCompileResult(
        ok: errors.isEmpty,
        recipeID: recipeID,
        componentMode: componentMode,
        componentSlots: componentSlots,
        requiredTypes: requiredTypes,
        unknownSlots: unknownSlots,
        unsafeSentenceComponentFrames: unsafeFrames,
        errors: errors
    )
}

private func recipeComponentMode(_ recipe: Recipe) -> RecipeComponentMode {
    recipe.componentMode == RecipeComponentMode.phraseComponents.rawValue ? .phraseComponents : .sentenceComponents
}

private func replaceRecipeSlots(
    in pattern: String,
    componentText: [RecipeComponentType: String],
    context: PlaceholderContext
) -> String {
    replaceSlots(pattern) { slot in
        if let type = componentType(slot) {
            return componentText[type] ?? "{\(slot)}"
        }
        return replacementForNonComponentSlot(slot, context: context) ?? "{\(slot)}"
    }
}

private func replaceSlots(_ pattern: String, replacement: (String) -> String) -> String {
    guard let regex = try? NSRegularExpression(pattern: #"\{([^{}]+)\}"#) else { return pattern }
    var output = ""
    var cursor = pattern.startIndex
    let matches = regex.matches(in: pattern, range: NSRange(pattern.startIndex..<pattern.endIndex, in: pattern))
    matches.forEach { match in
        guard let range = Range(match.range, in: pattern),
              let slotRange = Range(match.range(at: 1), in: pattern)
        else { return }
        output += String(pattern[cursor..<range.lowerBound])
        output += replacement(String(pattern[slotRange]))
        cursor = range.upperBound
    }
    output += String(pattern[cursor...])
    return output
}

private func replacementForNonComponentSlot(_ slot: String, context: PlaceholderContext) -> String? {
    switch slot {
    case "Name", "StudentName":
        return context.displayName
    case "Subject", "subject":
        return context.subject
    case "HeShe":
        return context.heShe
    case "heshe":
        return context.heSheLower
    case "HimHer", "himher":
        return context.himHer
    case "HisHer", "hisher":
        return context.hisHer
    default:
        return nil
    }
}

private func extractSlots(_ pattern: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: #"\{([^{}]+)\}"#) else { return [] }
    return regex.matches(in: pattern, range: NSRange(pattern.startIndex..<pattern.endIndex, in: pattern)).compactMap { match in
        guard let range = Range(match.range(at: 1), in: pattern) else { return nil }
        return String(pattern[range])
    }
}

private func componentType(_ slot: String) -> RecipeComponentType? {
    componentSlotOrder.first { $0.rawValue == slot }
}

private func sentenceComponentFrames(_ pattern: String) -> [String] {
    sentenceLikeSegments(pattern)
        .filter { segment in extractSlots(segment).contains { componentType($0) != nil } }
        .filter { unsupportedSentenceFrameResidue($0).isEmpty == false }
        .map(cleanSpacing)
}

private func sentenceLikeSegments(_ pattern: String) -> [String] {
    var segments: [String] = []
    var current = ""
    pattern.forEach { character in
        current.append(character)
        if ".!?".contains(character) {
            segments.append(current)
            current = ""
        }
    }
    if !current.isEmpty {
        segments.append(current)
    }
    return segments
}

private func unsupportedSentenceFrameResidue(_ segment: String) -> String {
    replaceSlots(segment) { slot in
        componentType(slot) == nil ? "{\(slot)}" : ""
    }
    .replacingOccurrences(of: #"[.!?\s]"#, with: "", options: .regularExpression)
    .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func normalizeRecipeText(_ text: String) -> String {
    text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: "\n\n")
        .map {
            cleanSpacing($0)
                .replacingOccurrences(of: #"([.!?])(?:\s*[.!?])+"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
                .replacingOccurrences(of: #"([.!?])([A-Z])"#, with: "$1 $2", options: .regularExpression)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
}

private func ensureSentence(_ text: String) -> String {
    let value = cleanSpacing(text)
    return value.range(of: #"[.!?]$"#, options: .regularExpression) == nil ? "\(value)." : value
}

private func looksSentenceLike(_ text: String, context: PlaceholderContext) -> Bool {
    let value = cleanSpacing(text)
    if value.range(of: #"[.!?]$"#, options: .regularExpression) != nil { return true }
    let escapedName = NSRegularExpression.escapedPattern(for: context.displayName)
    if !escapedName.isEmpty, value.range(of: #"^\#(escapedName)\b"#, options: [.regularExpression, .caseInsensitive]) != nil {
        return true
    }
    return value.range(of: #"^(he|she|they|[A-Z][a-z]+)\s+\w+"#, options: [.regularExpression, .caseInsensitive]) != nil
}

private func duplicateDisplayName(_ text: String, displayName: String) -> String? {
    let name = cleanSpacing(displayName)
    guard !name.isEmpty else { return nil }
    let escapedName = NSRegularExpression.escapedPattern(for: name)
    let pattern = #"(?:^|\s)("# + escapedName + #"\s+"# + escapedName + #")(?=\s|[,.!?;:]|$)"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          let matchRange = Range(match.range(at: 1), in: text)
    else { return nil }
    return String(text[matchRange])
}

private func firstName(from context: PlaceholderContext) -> String {
    cleanSpacing(context.displayName).components(separatedBy: .whitespaces).first?.ifEmpty(context.displayName) ?? context.displayName
}

private func fnv1aRecipeHash(_ value: String) -> UInt32 {
    var hash: UInt32 = 0x811c9dc5
    for codeUnit in value.utf16 {
        hash ^= UInt32(codeUnit)
        hash = hash &* 0x01000193
    }
    return hash
}

private func uniqueInOrder<T: Hashable>(_ values: [T]) -> [T] {
    var seen = Set<T>()
    return values.filter { seen.insert($0).inserted }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
