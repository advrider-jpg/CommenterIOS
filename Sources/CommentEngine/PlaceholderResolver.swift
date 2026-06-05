import CommenterDomain
import Foundation

public struct PlaceholderContext: Equatable, Sendable {
    public var displayName: String
    public var subject: String
    public var heShe: String
    public var heSheLower: String
    public var himHer: String
    public var hisHer: String
    public var specificTask: String?
    public var textType: String?
    public var unitTopic: String?
    public var context: String?

    public init(
        displayName: String,
        subject: String,
        heShe: String,
        heSheLower: String,
        himHer: String,
        hisHer: String,
        specificTask: String? = nil,
        textType: String? = nil,
        unitTopic: String? = nil,
        context: String? = nil
    ) {
        self.displayName = displayName
        self.subject = subject
        self.heShe = heShe
        self.heSheLower = heSheLower
        self.himHer = himHer
        self.hisHer = hisHer
        self.specificTask = specificTask
        self.textType = textType
        self.unitTopic = unitTopic
        self.context = context
    }
}

public struct PlaceholderResolutionResult: Equatable, Sendable {
    public var text: String
    public var unresolved: [String]
    public var missingContext: [String]

    public init(text: String, unresolved: [String], missingContext: [String]) {
        self.text = text
        self.unresolved = unresolved
        self.missingContext = missingContext
    }
}

public enum PlaceholderError: LocalizedError, Equatable {
    case unresolved(label: String, placeholders: [String])

    public var errorDescription: String? {
        switch self {
        case let .unresolved(label, placeholders):
            return "\(label) contains template text that must be replaced: \(placeholders.joined(separator: ", "))"
        }
    }
}

public func getDisplayName(student: Student, projectMetadata: ProjectMetadata) -> String {
    let firstName = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let lastName = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fullName = [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ")
    return (projectMetadata.useFirstNameOnly ? firstName.ifEmpty(fullName) : fullName).ifEmpty("Student")
}

public func getPronounSet(student: Student) -> (heShe: String, heSheLower: String, himHer: String, hisHer: String) {
    let pronouns = (student.pronouns ?? "").lowercased().replacingOccurrences(of: " ", with: "")
    let gender = (student.gender?.rawValue ?? "").lowercased()
    let mode: String
    if pronouns.contains("they/them") {
        mode = "neutral"
    } else if pronouns.contains("she/her") || gender == "f" {
        mode = "feminine"
    } else if pronouns.contains("he/him") || gender == "m" {
        mode = "masculine"
    } else {
        mode = "neutral"
    }

    switch mode {
    case "masculine":
        return ("He", "he", "him", "his")
    case "feminine":
        return ("She", "she", "her", "her")
    default:
        return ("They", "they", "them", "their")
    }
}

public func buildPlaceholderContext(
    student: Student,
    subject: String,
    result: AchievementResult,
    projectMetadata: ProjectMetadata,
    overrides: [String: String] = [:]
) -> PlaceholderContext {
    let pronouns = getPronounSet(student: student)
    let focus = result.focusStrand == "none" ? nil : result.focusStrand?.trimmedNonEmpty
    let evidence = result.evidenceText?.trimmedNonEmpty
    return PlaceholderContext(
        displayName: overrides["displayName"] ?? getDisplayName(student: student, projectMetadata: projectMetadata),
        subject: overrides["subject"] ?? subject,
        heShe: overrides["heShe"] ?? pronouns.heShe,
        heSheLower: overrides["heSheLower"] ?? pronouns.heSheLower,
        himHer: overrides["himHer"] ?? pronouns.himHer,
        hisHer: overrides["hisHer"] ?? pronouns.hisHer,
        specificTask: overrides["specificTask"] ?? evidence,
        textType: overrides["textType"] ?? normalizeReportContextField(result.textType),
        unitTopic: overrides["unitTopic"] ?? focus,
        context: overrides["context"] ?? normalizeReportContextField(result.learningContext)
    )
}

public func resolveReportPlaceholders(text: String, context: PlaceholderContext) -> PlaceholderResolutionResult {
    var rendered = text
        .replacingOccurrences(of: "{Name}", with: context.displayName)
        .replacingOccurrences(of: "{StudentName}", with: context.displayName)
        .replacingOccurrences(of: "{Subject}", with: context.subject)
        .replacingOccurrences(of: "{subject}", with: context.subject)
        .replacingOccurrences(of: "{HeShe}", with: context.heShe)
        .replacingOccurrences(of: "{heshe}", with: context.heSheLower)
        .replacingOccurrences(of: "{HimHer}", with: context.himHer)
        .replacingOccurrences(of: "{himher}", with: context.himHer)
        .replacingOccurrences(of: "{HisHer}", with: context.hisHer)
        .replacingOccurrences(of: "{hisher}", with: context.hisHer)

    var missingContext = Set<String>()
    bracketPlaceholders(in: rendered).forEach { token in
        if let replacement = replacement(for: token, context: context) {
            rendered = rendered.replacingOccurrences(of: token, with: replacement)
        } else if contextPlaceholderKeys[token.lowercased()] != nil {
            missingContext.insert(token)
        }
    }

    return PlaceholderResolutionResult(
        text: cleanSpacing(rendered),
        unresolved: findUnresolvedPlaceholders(rendered),
        missingContext: missingContext.sorted()
    )
}

public func canResolveReportText(_ text: String, context: PlaceholderContext) -> Bool {
    let result = resolveReportPlaceholders(text: text, context: context)
    return result.unresolved.isEmpty && result.missingContext.isEmpty
}

public func findUnresolvedPlaceholders(_ text: String) -> [String] {
    matches(pattern: #"\[[^\]]+\]|\{[^}]+\}"#, in: text)
}

public func assertNoUnresolvedPlaceholders(_ text: String, label: String) throws {
    let unresolved = findUnresolvedPlaceholders(text)
    guard unresolved.isEmpty else {
        throw PlaceholderError.unresolved(label: label, placeholders: unresolved)
    }
}

public func cleanSpacing(_ text: String) -> String {
    text
        .replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"(?:\s*\.\s*){2,}"#, with: ". ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

public func normalizeSentenceCase(_ text: String, displayName: String, protectedTerms: [String] = []) -> String {
    text
        .components(separatedBy: "\n\n")
        .map { paragraph in
            var result = capitalizeSentenceStarts(paragraph)
            let starts = sentenceStartOffsets(in: result)
            let protectedRanges = protectedTermRanges(in: result, terms: [displayName] + protectedTerms)
            result = replacePronounWords(in: result) { word, offset in
                if starts.contains(offset) { return word }
                if isInsideProtectedRange(offset: offset, length: word.count, ranges: protectedRanges) { return word }
                return word.lowercased()
            }
            return result
        }
        .joined(separator: "\n\n")
}

public func normalizeReportContextField(_ value: String?) -> String? {
    guard let value else { return nil }
    let normalized = value
        .replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"[.!?;:]+$"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let emptyMarkers = ["", "n/a", "na", "not applicable", "none", "null", "-", "\u{2014}"]
    guard !emptyMarkers.contains(normalized.lowercased()) else { return nil }
    guard normalized.count <= 120 else { return nil }
    guard findUnresolvedPlaceholders(normalized).isEmpty else { return nil }
    return normalized
}

private let studentNamePlaceholders: Set<String> = ["[student name]", "[studentname]", "[student]", "[name]"]
private let contextPlaceholderKeys: [String: KeyPath<PlaceholderContext, String?>] = [
    "[specific task]": \.specificTask,
    "[text type]": \.textType,
    "[unit/topic]": \.unitTopic,
    "[context]": \.context
]

private func replacement(for token: String, context: PlaceholderContext) -> String? {
    let normalized = token.lowercased()
    if studentNamePlaceholders.contains(normalized) { return context.displayName }
    if normalized == "[subject]" { return context.subject }
    if normalized == "[he/she]" { return token.contains("H") ? context.heShe : context.heSheLower }
    if normalized == "[she/her]" { return context.heSheLower == "she" ? "she" : context.heSheLower == "he" ? "he" : "they" }
    if normalized == "[his/her]" { return token.contains("H") ? context.hisHer.capitalizedFirst : context.hisHer }
    if normalized == "[him/her]" { return token.contains("H") ? context.himHer.capitalizedFirst : context.himHer }
    if let keyPath = contextPlaceholderKeys[normalized], let value = context[keyPath: keyPath]?.trimmedNonEmpty {
        return value
    }
    return nil
}

private func bracketPlaceholders(in text: String) -> [String] {
    matches(pattern: #"\[[^\]]+\]"#, in: text)
}

private func matches(pattern: String, in text: String) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    var seen = Set<String>()
    return regex.matches(in: text, range: range).compactMap { match -> String? in
        guard let range = Range(match.range, in: text) else { return nil }
        let value = String(text[range])
        guard !seen.contains(value) else { return nil }
        seen.insert(value)
        return value
    }
}

private func capitalizeSentenceStarts(_ text: String) -> String {
    replaceAll(pattern: #"(^|[.!?]\s+)([a-z])"#, in: text) { match in
        guard let prefix = match.groups[safe: 0], let letter = match.groups[safe: 1] else { return match.value }
        return "\(prefix)\(letter.uppercased())"
    }
}

private func sentenceStartOffsets(in text: String) -> Set<Int> {
    guard let regex = try? NSRegularExpression(pattern: #"[.!?]\s+"#) else { return [0] }
    var starts: Set<Int> = [0]
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    regex.matches(in: text, range: nsRange).forEach { match in
        starts.insert(match.range.location + match.range.length)
    }
    return starts
}

private func protectedTermRanges(in text: String, terms: [String]) -> [Range<Int>] {
    terms
        .map(cleanSpacing)
        .filter { !$0.isEmpty }
        .flatMap { term -> [Range<Int>] in
            var ranges: [Range<Int>] = []
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: term, range: searchStart..<text.endIndex) {
                let nsRange = NSRange(range, in: text)
                ranges.append(nsRange.location..<(nsRange.location + nsRange.length))
                searchStart = range.upperBound
            }
            return ranges
        }
}

private func isInsideProtectedRange(offset: Int, length: Int, ranges: [Range<Int>]) -> Bool {
    ranges.contains { range in
        offset >= range.lowerBound && offset + length <= range.upperBound
    }
}

private func replacePronounWords(in text: String, replacement: (String, Int) -> String) -> String {
    replaceAll(pattern: #"\b(He|She|They|Him|Her|His|Them|Their)\b"#, in: text) { match in
        replacement(match.value, match.utf16Offset)
    }
}

private struct RegexMatch {
    var value: String
    var range: Range<String.Index>
    var utf16Offset: Int
    var groups: [String]
}

private func replaceAll(
    pattern: String,
    in text: String,
    options: NSRegularExpression.Options = [],
    replacement: (RegexMatch) -> String
) -> String {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return text }
    var output = ""
    var cursor = text.startIndex
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    regex.matches(in: text, range: nsRange).forEach { match in
        guard let range = Range(match.range, in: text) else { return }
        let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
            let groupRange = match.range(at: index)
            guard groupRange.location != NSNotFound, let range = Range(groupRange, in: text) else { return nil }
            return String(text[range])
        }
        output += String(text[cursor..<range.lowerBound])
        output += replacement(RegexMatch(value: String(text[range]), range: range, utf16Offset: match.range.location, groups: groups))
        cursor = range.upperBound
    }
    output += String(text[cursor...])
    return output
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var capitalizedFirst: String {
        guard let first = self.first else { return self }
        return first.uppercased() + String(dropFirst())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
