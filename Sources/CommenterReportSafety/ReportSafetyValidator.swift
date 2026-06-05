import CommenterDomain
import Foundation

public struct ReportValidationContext: Codable, Equatable, Sendable {
    public var student: Student
    public var projectMetadata: ProjectMetadata
    public var subject: String
    public var allowedFacts: [ReportSafeFact]
    public var deterministicDraft: String?
    public var knownStudents: [Student]
    public var achievementLevel: AchievementLevel?
    public var forbiddenMentions: [String]
    public var requiredMentions: [String]
    public var maximumCharacters: Int
    public var validatedAt: Int64

    public init(
        student: Student,
        projectMetadata: ProjectMetadata,
        subject: String,
        allowedFacts: [ReportSafeFact] = [],
        deterministicDraft: String? = nil,
        knownStudents: [Student] = [],
        achievementLevel: AchievementLevel? = nil,
        forbiddenMentions: [String] = [],
        requiredMentions: [String] = [],
        maximumCharacters: Int = ProjectLimits.reportTextCharacters,
        validatedAt: Int64 = 0
    ) {
        self.student = student
        self.projectMetadata = projectMetadata
        self.subject = subject
        self.allowedFacts = allowedFacts
        self.deterministicDraft = deterministicDraft
        self.knownStudents = knownStudents
        self.achievementLevel = achievementLevel
        self.forbiddenMentions = forbiddenMentions
        self.requiredMentions = requiredMentions
        self.maximumCharacters = maximumCharacters
        self.validatedAt = validatedAt
    }
}

public enum ReportSafetyValidator {
    public static func validate(text: String, context: ReportValidationContext) -> ReportValidationSummary {
        var findings: [ReportValidationFinding] = []
        findings.append(contentsOf: placeholderFindings(text))
        findings.append(contentsOf: nameFindings(text, context: context))
        findings.append(contentsOf: pronounFindings(text, context: context))
        findings.append(contentsOf: forbiddenMentionFindings(text, context: context))
        findings.append(contentsOf: requiredMentionFindings(text, context: context))
        findings.append(contentsOf: sensitiveFindings(text, context: context))
        if !findings.contains(where: { $0.severity == .block }) {
            findings.append(contentsOf: unsupportedFactFindings(text, context: context))
            findings.append(contentsOf: toneFindings(text, context: context))
            findings.append(contentsOf: lengthFindings(text, context: context))
            findings.append(contentsOf: layoutFindings(text))
        }

        let status: ReportValidationStatus
        if findings.contains(where: { $0.severity == .block }) {
            status = .blocked
        } else if findings.isEmpty {
            status = .passed
        } else {
            status = .passedWithWarnings
        }

        return ReportValidationSummary(
            status: status,
            findings: findings.enumerated().map { index, finding in
                var next = finding
                next.id = "\(finding.category.rawValue)-\(index + 1)-\(stableTextFingerprint(finding.excerpt ?? finding.message))"
                return next
            },
            validatedAt: context.validatedAt,
            textFingerprint: stableTextFingerprint(text)
        )
    }
}

private func placeholderFindings(_ text: String) -> [ReportValidationFinding] {
    let unfinishedMarkerPattern = "\\b(?:" + ["TO" + "DO", "TBD"].joined(separator: "|") + ")\\b"
    let tokens = matches(pattern: #"\{\{[^}]+\}\}|\[[^\]]+\]|\{[^}]+\}|"# + unfinishedMarkerPattern, in: text, options: [.caseInsensitive])
    return unique(tokens).map {
        ReportValidationFinding(
            id: "",
            severity: .block,
            category: .placeholder,
            message: "Report text contains template or unfinished placeholder text.",
            excerpt: $0,
            suggestedFix: "Replace the placeholder with final teacher-approved report text."
        )
    }
}

private func forbiddenMentionFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    context.forbiddenMentions
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { containsWholePhrase($0, in: text) }
        .map { mention in
            ReportValidationFinding(
                id: "",
                severity: .block,
                category: .forbiddenMention,
                message: "The report includes a detail the teacher marked as do-not-mention.",
                excerpt: mention,
                suggestedFix: "Remove the do-not-mention detail before approval or export."
            )
        }
}

private func requiredMentionFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    context.requiredMentions
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .filter { !containsWholePhrase($0, in: text) }
        .map { mention in
            ReportValidationFinding(
                id: "",
                severity: .block,
                category: .requiredMention,
                message: "The report is missing a detail the teacher marked as required.",
                excerpt: mention,
                suggestedFix: "Add the required detail before approval or export, or remove it from this draft's required mentions."
            )
        }
}

private func nameFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    var findings: [ReportValidationFinding] = []
    let studentDisplayName = displayName(context.student, useFirstNameOnly: context.projectMetadata.useFirstNameOnly)
    let firstName = context.student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let lastName = context.student.lastName.trimmingCharacters(in: .whitespacesAndNewlines)

    if !studentDisplayName.isEmpty, !containsWholePhrase(studentDisplayName, in: text), !containsWholePhrase(firstName, in: text) {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .warning,
            category: .name,
            message: "The report may not name the selected student.",
            suggestedFix: "Confirm the final text clearly refers to the selected student."
        ))
    }

    if context.projectMetadata.useFirstNameOnly, !lastName.isEmpty, containsWholePhrase(lastName, in: text) {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .block,
            category: .name,
            message: "The report includes a last name while the project is set to first-name-only output.",
            excerpt: lastName,
            suggestedFix: "Remove the last name or change the project display setting."
        ))
    }

    context.knownStudents
        .filter { $0.id != context.student.id }
        .flatMap { other in [displayName(other, useFirstNameOnly: false), other.firstName, other.lastName] }
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && containsWholePhrase($0, in: text) }
        .forEach { otherName in
            findings.append(ReportValidationFinding(
                id: "",
                severity: .block,
                category: .name,
                message: "The report appears to mention another student.",
                excerpt: otherName,
                suggestedFix: "Remove names that do not belong to this report."
            ))
        }

    if containsWholePhrase("Student", in: text) && !firstName.localizedCaseInsensitiveContains("student") {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .block,
            category: .name,
            message: "The report appears to contain a generic student placeholder.",
            excerpt: "Student",
            suggestedFix: "Replace the placeholder with the student's report-safe name."
        ))
    }

    return findings
}

private func pronounFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    let expected = expectedPronounSet(context.student)
    guard !expected.subject.isEmpty else { return [] }
    let observed = Set(matches(pattern: #"\b(?:he|she|they|him|her|them|his|their)\b"#, in: text, options: [.caseInsensitive]).map { $0.lowercased() })
    guard !observed.isEmpty else { return [] }

    let expectedWords = Set([expected.subject, expected.object, expected.possessive])
    let mismatches = observed.subtracting(expectedWords).sorted()
    return mismatches.map {
        ReportValidationFinding(
            id: "",
            severity: .block,
            category: .pronoun,
            message: "The report uses a pronoun that does not match the selected student's pronouns.",
            excerpt: $0,
            suggestedFix: "Use \(expected.subject)/\(expected.object)/\(expected.possessive) consistently."
        )
    }
}

private func sensitiveFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    let allowed = allowedSourceText(context)
    return sensitivePatterns.compactMap { pattern in
        guard let match = firstMatch(pattern: pattern, in: text), !containsWholePhrase(match, in: allowed) else {
            return nil
        }
        return ReportValidationFinding(
            id: "",
            severity: .block,
            category: .sensitiveInformation,
            message: "The report mentions sensitive information that is not allowed by the default report policy.",
            excerpt: match,
            suggestedFix: "Remove the sensitive detail unless an explicit reviewed policy allows it."
        )
    }
}

private func unsupportedFactFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    let allowed = allowedSourceText(context)
    return unsupportedClaimPatterns.compactMap { pattern in
        guard let match = firstMatch(pattern: pattern, in: text), !containsWholePhrase(match, in: allowed) else {
            return nil
        }
        return ReportValidationFinding(
            id: "",
            severity: .warning,
            category: .unsupportedFact,
            message: "The report may include a fact or claim that is not present in the supplied evidence.",
            excerpt: match,
            suggestedFix: "Confirm the claim is supported by report-safe evidence or remove it."
        )
    }
}

private func toneFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    let harsh = harshTonePatterns.compactMap { firstMatch(pattern: $0, in: text) }
    var findings = harsh.map {
        ReportValidationFinding(
            id: "",
            severity: .block,
            category: .tone,
            message: "The report uses harsh or shaming language.",
            excerpt: $0,
            suggestedFix: "Rewrite using neutral, specific, teacher-safe language."
        )
    }

    if [.beginning, .developing].contains(context.achievementLevel), firstMatch(pattern: #"\b(?:brilliant|exceptional|outstanding|top of the class)\b"#, in: text) != nil {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .warning,
            category: .tone,
            message: "The report may overstate achievement relative to the supplied level.",
            suggestedFix: "Check that praise matches the recorded achievement level."
        ))
    }
    return findings
}

private func lengthFindings(_ text: String, context: ReportValidationContext) -> [ReportValidationFinding] {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count > context.maximumCharacters {
        return [ReportValidationFinding(
            id: "",
            severity: .block,
            category: .length,
            message: "The report is longer than the configured export limit.",
            suggestedFix: "Shorten the report before export."
        )]
    }
    if !trimmed.isEmpty, words(in: trimmed).count < 8 {
        return [ReportValidationFinding(
            id: "",
            severity: .warning,
            category: .length,
            message: "The report is very short.",
            suggestedFix: "Confirm the report gives families enough useful detail."
        )]
    }
    return []
}

private func layoutFindings(_ text: String) -> [ReportValidationFinding] {
    var findings: [ReportValidationFinding] = []
    if firstMatch(pattern: #"(?m)^\s*(?:[-*]|\d+\.)\s+"#, in: text) != nil {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .warning,
            category: .layout,
            message: "The report contains list formatting.",
            suggestedFix: "Use normal report paragraphs unless the export layout explicitly allows lists."
        ))
    }
    if firstMatch(pattern: #"(?m)^\s*#{1,6}\s+"#, in: text) != nil {
        findings.append(ReportValidationFinding(
            id: "",
            severity: .block,
            category: .layout,
            message: "The report contains markdown heading syntax.",
            suggestedFix: "Remove markdown formatting from final report text."
        ))
    }
    return findings
}

private let sensitivePatterns = [
    #"\b(?:ADHD|autis(?:m|tic)|dyslexi(?:a|c)|anxi(?:ety|ous)|depress(?:ion|ed)|therapy|therapist|medication|diagnos(?:is|ed)|disab(?:ility|led)|IEP|504 plan)\b"#,
    #"\b(?:family|home life|trauma|custody|poverty|religion|ethnicity|nationality|suspension|expelled|legal matter)\b"#
]

private let unsupportedClaimPatterns = [
    #"\b(?:always|never|guaranteed|best|top|first place|highest|lowest|won|competition)\b"#,
    #"\b(?:fractions|inference|persuasive devices|algebra|geometry|phonics|spelling age)\b"#
]

private let harshTonePatterns = [
    #"\b(?:lazy|careless|disruptive|weak|poor attitude|naughty|rude|defiant)\b"#
]

private func allowedSourceText(_ context: ReportValidationContext) -> String {
    let factText = context.allowedFacts
        .filter { $0.approvedForPrompt && $0.sensitivity == .reportSafe }
        .map(\.text)
    return ([context.subject, context.deterministicDraft ?? ""] + factText)
        .joined(separator: " ")
        .lowercased()
}

private func displayName(_ student: Student, useFirstNameOnly: Bool) -> String {
    let first = student.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    let last = student.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    let full = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
    return useFirstNameOnly ? (first.isEmpty ? full : first) : full
}

private func expectedPronounSet(_ student: Student) -> (subject: String, object: String, possessive: String) {
    let pronouns = (student.pronouns ?? "").lowercased().replacingOccurrences(of: " ", with: "")
    let gender = student.gender?.rawValue.lowercased() ?? ""
    if pronouns.contains("they/them") {
        return ("they", "them", "their")
    }
    if pronouns.contains("she/her") || gender == "f" {
        return ("she", "her", "her")
    }
    if pronouns.contains("he/him") || gender == "m" {
        return ("he", "him", "his")
    }
    return ("", "", "")
}

private func containsWholePhrase(_ phrase: String, in text: String) -> Bool {
    let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    let pattern = #"(?<![A-Za-z])"# + NSRegularExpression.escapedPattern(for: trimmed) + #"(?![A-Za-z])"#
    return text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
}

private func matches(pattern: String, in text: String, options: NSRegularExpression.Options = []) -> [String] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.matches(in: text, range: range).compactMap { match in
        guard let range = Range(match.range, in: text) else { return nil }
        return String(text[range])
    }
}

private func firstMatch(pattern: String, in text: String) -> String? {
    matches(pattern: pattern, in: text, options: [.caseInsensitive]).first
}

private func unique(_ values: [String]) -> [String] {
    var seen = Set<String>()
    return values.filter { seen.insert($0).inserted }
}

private func words(in text: String) -> [String] {
    text
        .components(separatedBy: .whitespacesAndNewlines)
        .map { $0.trimmingCharacters(in: .punctuationCharacters) }
        .filter { !$0.isEmpty }
}
