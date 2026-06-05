import CommenterDomain
import Foundation

enum TeacherTextKind: Equatable {
    case empty
    case completeSentence
    case verbPhrase
    case gerundPhrase
    case nounPhrase
    case contextPhrase
    case subordinateClause
    case negativeGrowthNote
    case fragment
    case unsafeOrUnclear
}

enum RepairIssueSeverity: Equatable {
    case warning
    case error
}

struct RepairIssue: Equatable {
    var code: String
    var severity: RepairIssueSeverity
    var message: String
    var original: String?
}

struct TeacherTextRepairContext: Equatable {
    enum PronounMode: Equatable {
        case masculine
        case feminine
        case neutral
    }

    var displayName: String
    var firstName: String
    var subjectPronoun: String
    var subjectPronounLower: String
    var objectPronoun: String
    var possessivePronoun: String
    var possessivePronounCapitalized: String
    var pronounMode: PronounMode
}

struct RepairedTextUnit: Equatable {
    var raw: String
    var text: String
    var kind: TeacherTextKind
}

struct RepairedEvidenceText: Equatable {
    var raw: String
    var units: [RepairedTextUnit]
    var sentences: [String]
    var appendedText: String
    var specificTaskPhrase: String?
    var canUseAsSpecificTask: Bool
    var issues: [RepairIssue]
}

struct RepairedReportNoteText: Equatable {
    var raw: String
    var units: [RepairedTextUnit]
    var sentences: [String]
    var text: String
    var issues: [RepairIssue]
}

func createTeacherTextRepairContext(student: Student, placeholderContext: PlaceholderContext) -> TeacherTextRepairContext {
    let pronounMode: TeacherTextRepairContext.PronounMode
    if placeholderContext.heSheLower == "he" {
        pronounMode = .masculine
    } else if placeholderContext.heSheLower == "she" {
        pronounMode = .feminine
    } else {
        pronounMode = .neutral
    }

    return TeacherTextRepairContext(
        displayName: placeholderContext.displayName,
        firstName: student.firstName.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(placeholderContext.displayName),
        subjectPronoun: placeholderContext.heShe,
        subjectPronounLower: placeholderContext.heSheLower,
        objectPronoun: placeholderContext.himHer,
        possessivePronoun: placeholderContext.hisHer,
        possessivePronounCapitalized: placeholderContext.hisHer.capitalizedFirst,
        pronounMode: pronounMode
    )
}

func repairEvidenceText(_ rawValue: String?, context: TeacherTextRepairContext) -> RepairedEvidenceText {
    let repaired = repairText(rawValue, context: context)
    let raw = rawValue ?? ""
    let phrase = phraseSafeEvidence(raw)
    return RepairedEvidenceText(
        raw: repaired.raw,
        units: repaired.units,
        sentences: repaired.sentences,
        appendedText: repaired.sentences.joined(separator: " "),
        specificTaskPhrase: phrase,
        canUseAsSpecificTask: phrase != nil,
        issues: repaired.issues
    )
}

func repairReportNoteText(_ rawValue: String?, context: TeacherTextRepairContext) -> RepairedReportNoteText {
    let repaired = repairText(rawValue, context: context)
    return RepairedReportNoteText(
        raw: repaired.raw,
        units: repaired.units,
        sentences: repaired.sentences,
        text: repaired.sentences.joined(separator: " "),
        issues: repaired.issues
    )
}

func hasBlockingRepairIssue(_ result: [RepairIssue]) -> Bool {
    result.contains { $0.severity == .error }
}

func blockingRepairMessage(label: String, issues: [RepairIssue]) -> String {
    guard let issue = issues.first(where: { $0.severity == .error }) else { return "" }
    return "\(label) could not be used safely: \(issue.message)"
}

private let placeholderPattern = #"\[[^\]]+\]|\{[^}]+\}"#
private let sentenceEndPattern = #"[.!?]$"#
private let leadingPronounPattern = #"^(he|she|they)\b"#
private let leadingNamePattern = #"^[A-Z][a-z]+\b"#
private let verbPhrasePattern = #"^(checks?|uses?|used|solves?|solved|shows?|showed|demonstrates?|demonstrated|applies?|applied|works?|worked|writes?|wrote|reads?|read|explains?|explained|identifies?|identified|analyses?|analysed|participates?|participated|contributes?|contributed|creates?|created|keeps?|kept|plans?|planned|listens?|listened|focuses?|focused|understands?|understood|improves?|improved|completes?|completed|attempts?|attempted|prefers?|organises?|organised|organizes?|organized)\b"#
private let gerundPattern = #"^(using|checking|solving|showing|demonstrating|applying|working|writing|reading|explaining|identifying|participating|contributing|creating|keeping|planning|listening|focusing|improving|completing|organising|organizing)\b"#
private let negativePattern = #"^(needs?|does not|doesn't|struggles? to|struggles with|finds it difficult to|requires? reminders? to|requires? support to)\b"#
private let subordinatePattern = #"^(because|when|while|although|if|as)\b"#
private let contextPattern = #"^(during|in|through|with|on|for|the|a|an)\b"#
private let negativeGrowthPrefixes = [
    #"^needs?\s+"#,
    #"^does not\s+"#,
    #"^doesn't\s+"#,
    #"^struggles?\s+to\s+"#,
    #"^struggles?\s+with\s+"#,
    #"^finds it difficult to\s+"#,
    #"^requires? reminders? to\s+"#,
    #"^requires? support to\s+"#
]
private let thirdPersonVerbs = [
    "analyse": "analyses",
    "apply": "applies",
    "attempt": "attempts",
    "check": "checks",
    "complete": "completes",
    "contribute": "contributes",
    "create": "creates",
    "demonstrate": "demonstrates",
    "explain": "explains",
    "focus": "focuses",
    "have": "has",
    "identify": "identifies",
    "improve": "improves",
    "keep": "keeps",
    "listen": "listens",
    "participate": "participates",
    "plan": "plans",
    "prefer": "prefers",
    "organise": "organises",
    "organize": "organizes",
    "read": "reads",
    "share": "shares",
    "show": "shows",
    "solve": "solves",
    "understand": "understands",
    "use": "uses",
    "work": "works",
    "write": "writes"
]
private let irregularPluralToSingular = [
    "are": "is",
    "do": "does",
    "have": "has",
    "were": "was"
]
private let irregularSingularToPlural = [
    "does": "do",
    "has": "have",
    "is": "are",
    "was": "were"
]
private let thirdPersonToBase = Dictionary(uniqueKeysWithValues: thirdPersonVerbs.map { ($0.value, $0.key) })
private let gerundToThirdPerson = [
    "using": "uses",
    "checking": "checks",
    "solving": "solves",
    "showing": "shows",
    "demonstrating": "demonstrates",
    "applying": "applies",
    "working": "works",
    "writing": "writes",
    "reading": "reads",
    "explaining": "explains",
    "identifying": "identifies",
    "participating": "participates",
    "contributing": "contributes",
    "creating": "creates",
    "keeping": "keeps",
    "planning": "plans",
    "listening": "listens",
    "focusing": "focuses",
    "improving": "improves",
    "completing": "completes",
    "organising": "organises",
    "organizing": "organizes"
]

private func repairText(_ rawValue: String?, context: TeacherTextRepairContext) -> (raw: String, units: [RepairedTextUnit], sentences: [String], issues: [RepairIssue]) {
    let raw = rawValue ?? ""
    var issues: [RepairIssue] = []
    guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return (raw, [], [], [])
    }
    if raw.count > 2_000 {
        issues.append(RepairIssue(code: "text-too-long", severity: .error, message: "Teacher text is too long to use safely in the report.", original: raw))
    }
    if matchesPattern(placeholderPattern, in: raw) {
        issues.append(RepairIssue(code: "placeholder", severity: .error, message: "Teacher text contains template placeholders that must be removed.", original: raw))
    }

    let units = splitUnits(raw).map { repairUnit($0, context: context) }
    return (raw, units, units.map(\.text).filter { !$0.isEmpty }, issues)
}

private func repairUnit(_ raw: String, context: TeacherTextRepairContext) -> RepairedTextUnit {
    var cleaned = normalizeLeadingPronoun(removeRepeatedName(cleanText(raw), context: context), context: context)
    if matchesPattern(#"^celebrate\s+"#, in: cleaned, options: [.caseInsensitive]) {
        cleaned = cleaned.replacingOccurrences(of: #"^celebrate\s+"#, with: "", options: [.regularExpression, .caseInsensitive])
    }

    let kind = classifyUnit(cleaned, context: context)
    let text: String
    switch kind {
    case .empty:
        text = ""
    case .completeSentence:
        text = ensureSentence(cleaned)
    case .negativeGrowthNote:
        text = repairNegativeGrowthNote(cleaned, context: context)
    case .subordinateClause:
        text = ensureSentence("This was evident \(stripTerminalPunctuation(cleaned))")
    case .verbPhrase:
        text = ensureSentence("\(context.displayName) \(stripTerminalPunctuation(cleaned))")
    case .gerundPhrase:
        text = repairGerundPhrase(cleaned, context: context)
    case .nounPhrase, .fragment:
        text = ensureSentence("\(context.displayName) shows \(stripTerminalPunctuation(cleaned))")
    case .contextPhrase:
        let phrase = stripTerminalPunctuation(cleaned)
        text = ensureSentence(matchesPattern(#"^(the|a|an)\b"#, in: phrase, options: [.caseInsensitive]) ? "This was evident in \(phrase)" : "This was evident \(phrase)")
    case .unsafeOrUnclear:
        text = cleaned
    }
    return RepairedTextUnit(raw: raw, text: text, kind: kind)
}

private func classifyUnit(_ text: String, context: TeacherTextRepairContext) -> TeacherTextKind {
    let normalized = cleanText(text)
    if normalized.isEmpty { return .empty }
    if matchesPattern(placeholderPattern, in: normalized) { return .unsafeOrUnclear }
    if matchesPattern(negativePattern, in: normalized, options: [.caseInsensitive]) { return .negativeGrowthNote }
    if matchesPattern(subordinatePattern, in: normalized, options: [.caseInsensitive]) { return .subordinateClause }
    if matchesPattern(gerundPattern, in: normalized, options: [.caseInsensitive]) { return .gerundPhrase }
    if matchesPattern(verbPhrasePattern, in: normalized, options: [.caseInsensitive]) { return .verbPhrase }

    let lower = normalized.lowercased()
    if lower.hasPrefix(context.displayName.lowercased())
        || lower.hasPrefix(context.firstName.lowercased())
        || matchesPattern(leadingPronounPattern, in: normalized, options: [.caseInsensitive]) {
        return .completeSentence
    }
    if matchesPattern(sentenceEndPattern, in: normalized), matchesPattern(leadingNamePattern, in: normalized) {
        return .completeSentence
    }
    if matchesPattern(contextPattern, in: normalized, options: [.caseInsensitive]) { return .contextPhrase }
    if normalized.split(whereSeparator: \.isWhitespace).count <= 6 { return .nounPhrase }
    return .fragment
}

private func phraseSafeEvidence(_ raw: String) -> String? {
    let text = stripTerminalPunctuation(raw)
    if text.isEmpty || text.count > 120 { return nil }
    if matchesPattern(placeholderPattern, in: text)
        || matchesPattern(leadingPronounPattern, in: text, options: [.caseInsensitive])
        || matchesPattern(verbPhrasePattern, in: text, options: [.caseInsensitive])
        || matchesPattern(negativePattern, in: text, options: [.caseInsensitive])
        || matchesPattern(subordinatePattern, in: text, options: [.caseInsensitive]) {
        return nil
    }
    if matchesPattern(sentenceEndPattern, in: raw)
        || matchesPattern(#"\b(is|are|was|were|has|have|had|can|could|will|would|should)\b"#, in: text, options: [.caseInsensitive]) {
        return nil
    }
    return text
}

private func repairNegativeGrowthNote(_ raw: String, context: TeacherTextRepairContext) -> String {
    let phrase = stripTerminalPunctuation(raw)
    let constructive: String
    if let match = firstMatch(pattern: #"^(requires? support to|needs? support to|finds it difficult to|struggles? to|needs? to)\s+(.+)$"#, in: phrase, options: [.caseInsensitive]), let remainder = match.groups[safe: 1] {
        constructive = "support to \(remainder)"
    } else if let match = firstMatch(pattern: #"^(requires? reminders? to|needs? reminders? to)\s+(.+)$"#, in: phrase, options: [.caseInsensitive]), let remainder = match.groups[safe: 1] {
        constructive = "reminders to \(remainder)"
    } else if let match = firstMatch(pattern: #"^struggles? with\s+(.+)$"#, in: phrase, options: [.caseInsensitive]), let remainder = match.groups[safe: 0] {
        constructive = "continued practice with \(remainder)"
    } else if let match = firstMatch(pattern: #"^(does not|doesn't)\s+(.+)$"#, in: phrase, options: [.caseInsensitive]), let remainder = match.groups[safe: 1] {
        constructive = "support to \(remainder)"
    } else if let match = firstMatch(pattern: #"^needs?\s+(.+)$"#, in: phrase, options: [.caseInsensitive]), let remainder = match.groups[safe: 0] {
        constructive = "support with \(remainder)"
    } else {
        constructive = "continued practice with this skill"
    }
    return ensureSentence("\(context.displayName) would benefit from \(constructive)")
}

private func repairGerundPhrase(_ raw: String, context: TeacherTextRepairContext) -> String {
    let phrase = stripTerminalPunctuation(raw)
    guard let match = firstMatch(pattern: #"^([a-z]+)(\b.*)$"#, in: phrase, options: [.caseInsensitive]),
          let gerund = match.groups[safe: 0]?.lowercased(),
          let remainder = match.groups[safe: 1],
          let finiteVerb = gerundToThirdPerson[gerund]
    else {
        return ensureSentence("\(context.displayName) demonstrates this skill when \(phrase)")
    }
    return ensureSentence("\(context.displayName) \(finiteVerb)\(remainder)")
}

private func normalizeLeadingPronoun(_ text: String, context: TeacherTextRepairContext) -> String {
    guard let match = firstMatch(pattern: leadingPronounPattern, in: text, options: [.caseInsensitive]) else {
        return text
    }
    let original = match.value
    let startsUppercase = original.first.map { String($0).rangeOfCharacter(from: .uppercaseLetters) != nil } ?? false
    let replacement = match.range.lowerBound == text.startIndex && startsUppercase
        ? context.subjectPronoun
        : context.subjectPronounLower
    var remainder = String(text[match.range.upperBound...])
    let sourceMode = modeForSubjectPronoun(original) ?? context.pronounMode
    remainder = adjustAgreementVerbs(in: remainder, from: sourceMode, to: context.pronounMode)
    remainder = normalizeRelatedPronouns(remainder, context: context)
    return "\(replacement)\(remainder)"
}

private func modeForSubjectPronoun(_ pronoun: String) -> TeacherTextRepairContext.PronounMode? {
    if pronoun.range(of: #"^he$"#, options: [.regularExpression, .caseInsensitive]) != nil { return .masculine }
    if pronoun.range(of: #"^she$"#, options: [.regularExpression, .caseInsensitive]) != nil { return .feminine }
    if pronoun.range(of: #"^they$"#, options: [.regularExpression, .caseInsensitive]) != nil { return .neutral }
    return nil
}

private func adjustVerb(_ verb: String, from sourceMode: TeacherTextRepairContext.PronounMode, to targetMode: TeacherTextRepairContext.PronounMode) -> String {
    let lower = verb.lowercased()
    let adjusted: String
    if sourceMode == .neutral, targetMode != .neutral {
        adjusted = irregularPluralToSingular[lower] ?? thirdPersonVerbs[lower] ?? lower
    } else if sourceMode != .neutral, targetMode == .neutral {
        adjusted = irregularSingularToPlural[lower] ?? thirdPersonToBase[lower] ?? lower
    } else {
        adjusted = lower
    }
    return verb.first.map { String($0).rangeOfCharacter(from: .uppercaseLetters) != nil } == true ? adjusted.capitalizedFirst : adjusted
}

private func adjustAgreementVerbs(in text: String, from sourceMode: TeacherTextRepairContext.PronounMode, to targetMode: TeacherTextRepairContext.PronounMode) -> String {
    guard sourceMode != targetMode, (sourceMode == .neutral || targetMode == .neutral) else { return text }
    let withLeadingVerb = replaceFirst(pattern: #"^(\s+)([a-z]+)\b"#, in: text, options: [.caseInsensitive]) { match in
        guard let whitespace = match.groups[safe: 0], let verb = match.groups[safe: 1] else { return match.value }
        let adjusted = adjustVerb(verb, from: sourceMode, to: targetMode)
        return adjusted == verb ? match.value : "\(whitespace)\(adjusted)"
    }
    return replaceAll(pattern: #"\b(and|or)\s+([a-z]+)\b"#, in: withLeadingVerb, options: [.caseInsensitive]) { match in
        guard let conjunction = match.groups[safe: 0], let verb = match.groups[safe: 1] else { return match.value }
        let adjusted = adjustVerb(verb, from: sourceMode, to: targetMode)
        return adjusted == verb ? match.value : "\(conjunction) \(adjusted)"
    }
}

private func normalizeRelatedPronouns(_ text: String, context: TeacherTextRepairContext) -> String {
    replaceAll(pattern: #"\b(their|his|her)\s+([a-z][a-z'-]*)"#, in: text, options: [.caseInsensitive]) { match in
        guard let noun = match.groups[safe: 1] else { return match.value }
        return "\(context.possessivePronoun) \(noun)"
    }
    .replacingOccurrences(of: #"\b(them|him|her)\b"#, with: context.objectPronoun, options: [.regularExpression, .caseInsensitive])
}

private func conjugateLeadingVerb(in text: String) -> String {
    guard let match = firstMatch(pattern: #"^(\s+)([a-z]+)\b"#, in: text, options: [.caseInsensitive]) else {
        return text
    }
    let verb = match.groups[safe: 1]?.lowercased() ?? ""
    guard let conjugated = thirdPersonVerbs[verb] else { return text }
    return text.replacingCharacters(in: match.range, with: "\(match.groups[safe: 0] ?? "")\(conjugated)")
}

private func removeRepeatedName(_ text: String, context: TeacherTextRepairContext) -> String {
    let display = NSRegularExpression.escapedPattern(for: context.displayName)
    let first = NSRegularExpression.escapedPattern(for: context.firstName)
    let collapsedDisplay = text.replacingOccurrences(of: #"\b\#(display)\s+\#(display)\b"#, with: context.displayName, options: [.regularExpression, .caseInsensitive])
    return collapsedDisplay.replacingOccurrences(of: #"\b\#(first)\s+\#(first)\b"#, with: context.firstName, options: [.regularExpression, .caseInsensitive])
}

private func splitUnits(_ text: String) -> [String] {
    let normalized = cleanLineEndings(text)
    return unitSeparatorRegex
        .stringByReplacingMatches(in: normalized, range: NSRange(normalized.startIndex..<normalized.endIndex, in: normalized), withTemplate: "\u{1f}")
        .components(separatedBy: "\u{1f}")
        .map(cleanText)
        .filter { !$0.isEmpty }
}

private let unitSeparatorRegex = try! NSRegularExpression(pattern: #"(?<=[.!?])\s+|\s*[;\n]\s*"#)

private func cleanLineEndings(_ text: String) -> String {
    text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
}

private func cleanText(_ value: String) -> String {
    value
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .replacingOccurrences(of: #"\s+([,.!?;:])"#, with: "$1", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

private func stripTerminalPunctuation(_ text: String) -> String {
    cleanText(text).replacingOccurrences(of: #"[.!?]+$"#, with: "", options: .regularExpression)
}

private func ensureSentence(_ text: String) -> String {
    let trimmed = sentenceCase(text)
    return trimmed.isEmpty || matchesPattern(sentenceEndPattern, in: trimmed) ? trimmed : "\(trimmed)."
}

private func sentenceCase(_ text: String) -> String {
    let trimmed = cleanText(text)
    guard let first = trimmed.first else { return trimmed }
    return first.uppercased() + String(trimmed.dropFirst())
}

private func replaceWord(_ word: String, with replacement: String, in text: String) -> String {
    text.replacingOccurrences(of: #"\b\#(NSRegularExpression.escapedPattern(for: word))\b"#, with: replacement, options: [.regularExpression, .caseInsensitive])
}

private struct RegexMatch {
    var value: String
    var range: Range<String.Index>
    var groups: [String]
}

private func firstMatch(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> RegexMatch? {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
    let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: nsRange),
          let range = Range(match.range, in: text)
    else {
        return nil
    }
    let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
        let groupRange = match.range(at: index)
        guard groupRange.location != NSNotFound, let range = Range(groupRange, in: text) else { return nil }
        return String(text[range])
    }
    return RegexMatch(value: String(text[range]), range: range, groups: groups)
}

private func matchesPattern(_ pattern: String, in text: String, options: NSRegularExpression.Options = []) -> Bool {
    firstMatch(pattern: pattern, in: text, options: options) != nil
}

private func replaceFirst(
    pattern: String,
    in text: String,
    options: NSRegularExpression.Options = [],
    replacement: (RegexMatch) -> String
) -> String {
    guard let match = firstMatch(pattern: pattern, in: text, options: options) else { return text }
    return text.replacingCharacters(in: match.range, with: replacement(match))
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
        output += replacement(RegexMatch(value: String(text[range]), range: range, groups: groups))
        cursor = range.upperBound
    }
    output += String(text[cursor...])
    return output
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }

    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + String(dropFirst())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
