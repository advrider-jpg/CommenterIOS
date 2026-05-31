import CommentEngine
import CommenterDomain
import Foundation

public let maxResultFreeTextLength = 2_000
public let maxReportEmphasisNoteLength = 180

public struct ImportValidationError: LocalizedError, Equatable {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}

public enum ImportValidation {
    public static func parseRosterImportCSV(
        _ text: String,
        existingRoster: [Student],
        createID: () throws -> String
    ) throws -> [Student] {
        try parseRosterImportRows(
            CSVParser.parseCSV(text),
            existingRoster: existingRoster,
            createID: createID
        )
    }

    public static func parseRosterImportRows(
        _ parsed: CSVParseResult,
        existingRoster: [Student],
        createID: () throws -> String
    ) throws -> [Student] {
        try assertCSVHeaders(parsed.headers, required: ["First Name", "Last Name", "Year Level"])

        var seen = Set<String>()
        var usedIDs = Set(existingRoster.map(\.id))
        var rejectedRows: [String] = []
        var validStudents: [Student] = []

        for (index, row) in parsed.rows.enumerated() {
            let rowLabel = "row \(index + 2)"
            let firstName = firstCSVValue(row, aliases: ["FirstName", "First Name"])
            let lastName = firstCSVValue(row, aliases: ["LastName", "Last Name"])
            let yearRaw = firstCSVValue(row, aliases: ["YearLevel", "Year Level", "Year"])
            let yearLevel = normalizeYearLevel(yearRaw)

            guard !firstName.isEmpty, !lastName.isEmpty, let yearLevel else {
                rejectedRows.append("\(rowLabel): first name, last name, and explicit Year 5/Year 6 are required")
                continue
            }

            let duplicateKey = studentKey(firstName: firstName, lastName: lastName, yearLevel: yearLevel.rawValue)
            guard !seen.contains(duplicateKey) else {
                rejectedRows.append("\(rowLabel): duplicate student \(firstName) \(lastName) (\(yearLevel.rawValue)) is not allowed")
                continue
            }
            seen.insert(duplicateKey)

            let genderRaw = CSVParser.value(in: row, matching: "Gender")
            guard let gender = normalizeImportedGender(genderRaw) else {
                rejectedRows.append("\(rowLabel): gender \"\(genderRaw)\" is not recognised; use Male, Female, M, F, or leave blank")
                continue
            }

            let attitudeRaw = firstCSVValue(row, aliases: ["Attitude", "AttitudeDescriptor"])
            let attitudeDescriptor = canonicalAttitude(attitudeRaw)
            if !attitudeRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, attitudeDescriptor == nil {
                rejectedRows.append("\(rowLabel): attitude descriptor \"\(attitudeRaw)\" is not recognised")
                continue
            }

            let id: String
            do {
                id = try createID().trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                rejectedRows.append("\(rowLabel): this student row could not be prepared safely; try importing again")
                continue
            }
            guard !id.isEmpty, !usedIDs.contains(id) else {
                rejectedRows.append("\(rowLabel): this student row could not be prepared safely; try importing again")
                continue
            }
            usedIDs.insert(id)

            validStudents.append(
                Student(
                    id: id,
                    firstName: firstName,
                    lastName: lastName,
                    gender: gender,
                    yearLevel: yearLevel,
                    internalTeacherNote: firstCSVValue(row, aliases: [
                        "PrivateTeacherNote",
                        "Private Teacher Note",
                        "Teacher Note",
                        "Comments",
                        "Notes"
                    ]).nilIfEmpty,
                    attitudeDescriptor: attitudeDescriptor
                )
            )
        }

        try throwImportErrors(kind: "students", validCount: validStudents.count, rejectedRows: rejectedRows)

        let existingKeys = Set(existingRoster.map { studentKey(firstName: $0.firstName, lastName: $0.lastName, yearLevel: $0.yearLevel.rawValue) })
        if let duplicate = validStudents.first(where: { existingKeys.contains(studentKey(firstName: $0.firstName, lastName: $0.lastName, yearLevel: $0.yearLevel.rawValue)) }) {
            throw ImportValidationError("\(duplicate.firstName) \(duplicate.lastName) (\(duplicate.yearLevel.rawValue)) is already in the roster. Existing project data was left unchanged.")
        }

        return validStudents
    }

    public static func parseResultsImportCSV(
        _ text: String,
        roster: [Student],
        selectedSubjects: [String: SelectedSubject]
    ) throws -> [AchievementResult] {
        try parseResultsImportRows(
            CSVParser.parseCSV(text),
            roster: roster,
            selectedSubjects: selectedSubjects
        )
    }

    public static func parseResultsImportRows(
        _ parsed: CSVParseResult,
        roster: [Student],
        selectedSubjects: [String: SelectedSubject]
    ) throws -> [AchievementResult] {
        try assertCSVHeaderAliases(parsed.headers, required: [
            .one("First Name"),
            .one("Last Name"),
            .one("Subject"),
            .any(["Achievement Level", "Level"])
        ])

        let subjectNames = Array(selectedSubjects.keys)
        let subjectsByNormalized = subjectNames.reduce(into: [String: String]()) { index, subject in
            index[normalizeSubjectLabel(subject)] = subject
        }
        var importedKeys = Set<String>()
        var rejectedRows: [String] = []
        var newResults: [AchievementResult] = []

        for (index, row) in parsed.rows.enumerated() {
            let rowLabel = "row \(index + 2)"
            let firstName = firstCSVValue(row, aliases: ["FirstName", "First Name"])
            let lastName = firstCSVValue(row, aliases: ["LastName", "Last Name"])
            let yearValue = firstCSVValue(row, aliases: ["YearLevel", "Year Level", "Year"])
            let subjectName = CSVParser.value(in: row, matching: "Subject")
            let level = firstCSVValue(row, aliases: ["AchievementLevel", "Achievement Level", "Level"])
            let focus = CSVParser.value(in: row, matching: "Focus")

            guard !firstName.isEmpty, !lastName.isEmpty, !subjectName.isEmpty, !level.isEmpty else {
                rejectedRows.append("\(rowLabel): first name, last name, subject, and achievement level are required")
                continue
            }

            guard let student = findStudentForResult(
                roster: roster,
                firstName: firstName,
                lastName: lastName,
                yearValue: yearValue,
                rowLabel: rowLabel,
                rejectedRows: &rejectedRows
            ) else {
                continue
            }

            if !yearValue.isEmpty {
                guard let normalizedYear = normalizeYearLevel(yearValue) else {
                    rejectedRows.append("\(rowLabel): Year Level must be Year 5 or Year 6")
                    continue
                }
                guard student.yearLevel == normalizedYear else {
                    rejectedRows.append("\(rowLabel): \(firstName) \(lastName) does not match \(normalizedYear.rawValue) in this project")
                    continue
                }
            }

            guard let canonicalSubjectName = subjectsByNormalized[normalizeSubjectLabel(subjectName)] else {
                rejectedRows.append("\(rowLabel): subject \"\(subjectName)\" is not selected in this project")
                continue
            }

            var canonicalFocus = focus
            if subjectRequiresConcreteFocus(canonicalSubjectName) {
                guard !focus.isEmpty else {
                    rejectedRows.append("\(rowLabel): \(canonicalSubjectName) requires a specific subject in Focus, such as Music or Digital Technologies")
                    continue
                }
                guard let matchedFocus = getConcreteFocusOptions(canonicalSubjectName).first(where: { normalizeSubjectLabel($0) == normalizeSubjectLabel(focus) }) else {
                    rejectedRows.append("\(rowLabel): Focus \"\(focus)\" is not a recognised specific subject for \(canonicalSubjectName)")
                    continue
                }
                canonicalFocus = matchedFocus
            }

            guard let achievementLevel = normalizeAchievementLevel(level) else {
                rejectedRows.append("\(rowLabel): achievement level \"\(level)\" is not recognised")
                continue
            }

            let resultKey = "\(student.id)::\(canonicalSubjectName)"
            guard !importedKeys.contains(resultKey) else {
                rejectedRows.append("\(rowLabel): duplicate result for \(firstName) \(lastName) / \(canonicalSubjectName)")
                continue
            }
            importedKeys.insert(resultKey)

            let evidenceText = CSVParser.value(in: row, matching: "Evidence")
            guard validateResultFreeText(evidenceText, rowLabel: rowLabel, fieldLabel: "Evidence", rejectedRows: &rejectedRows) else {
                continue
            }

            let commentsText = firstCSVValue(row, aliases: [
                "OptionalReportNote",
                "Optional Report Note",
                "ReportNote",
                "Report Note",
                "ReportEmphasisNote",
                "Report Emphasis Note",
                "Comments"
            ])
            guard commentsText.count <= maxReportEmphasisNoteLength else {
                rejectedRows.append("\(rowLabel): Optional report note must be \(maxReportEmphasisNoteLength) characters or fewer")
                continue
            }

            guard let textType = parseImportedReportContextField(
                firstCSVValue(row, aliases: ["Text Type", "TextType", "Genre", "Writing Type", "WritingType"]),
                rowLabel: rowLabel,
                fieldLabel: "Text type / genre",
                rejectedRows: &rejectedRows
            ) else {
                continue
            }
            guard let learningContext = parseImportedReportContextField(
                firstCSVValue(row, aliases: [
                    "Learning Context",
                    "LearningContext",
                    "Context",
                    "Activity",
                    "Activity Context",
                    "Investigation Context",
                    "Unit Context"
                ]),
                rowLabel: rowLabel,
                fieldLabel: "Learning context / activity",
                rejectedRows: &rejectedRows
            ) else {
                continue
            }

            guard let englishFocusTags = canonicalizeList(
                parseCommaSeparated(firstCSVValue(row, aliases: ["EnglishFocusAreas", "English Focus Areas", "EnglishFocusTags", "English Focus Tags"])),
                allowedValues: allowedEnglishFocusTags,
                rowLabel: rowLabel,
                fieldLabel: "English focus areas",
                rejectedRows: &rejectedRows,
                maxCount: 2
            ) else {
                continue
            }
            guard let mathProficiencies = canonicalizeList(
                parseCommaSeparated(firstCSVValue(row, aliases: ["MathematicsProficiencyAreas", "Mathematics Proficiency Areas", "MathProficiencies", "Math Proficiencies"])),
                allowedValues: allowedMathProficiencies,
                rowLabel: rowLabel,
                fieldLabel: "Mathematics proficiency areas",
                rejectedRows: &rejectedRows,
                maxCount: 2
            ) else {
                continue
            }
            guard let mathMindsetToggles = canonicalizeList(
                parseCommaSeparated(firstCSVValue(row, aliases: ["MathematicsLearningHabits", "Mathematics Learning Habits", "MathMindsets", "Math Mindsets"])),
                allowedValues: allowedMathMindsetToggles,
                rowLabel: rowLabel,
                fieldLabel: "Mathematics learning habits",
                rejectedRows: &rejectedRows
            ) else {
                continue
            }
            guard let nextStepGoals = canonicalizeList(
                parseCommaSeparated(firstCSVValue(row, aliases: ["NextStepGoals", "Next Step Goals"])),
                allowedValues: nextStepGoals(for: canonicalSubjectName),
                rowLabel: rowLabel,
                fieldLabel: "Next-step goals",
                rejectedRows: &rejectedRows,
                maxCount: 2
            ) else {
                continue
            }

            newResults.append(
                AchievementResult(
                    studentId: student.id,
                    subject: canonicalSubjectName,
                    achievementLevel: achievementLevel,
                    focusStrand: canonicalFocus,
                    evidenceText: evidenceText,
                    textType: textType.nilIfEmpty,
                    learningContext: learningContext.nilIfEmpty,
                    reportEmphasisNote: commentsText,
                    commentsText: "",
                    flags: [:],
                    englishFocusTags: englishFocusTags,
                    mathProficiencies: mathProficiencies,
                    mathMindsetToggles: mathMindsetToggles,
                    nextStepGoals: nextStepGoals
                )
            )
        }

        try throwImportErrors(kind: "results", validCount: newResults.count, rejectedRows: rejectedRows)
        return newResults
    }
}

private enum RequiredHeader {
    case one(String)
    case any([String])
}

private let attitudeAdjectives = [
    "bright",
    "committed",
    "confident",
    "conscientious",
    "curious",
    "dedicated",
    "determined",
    "diligent",
    "eager",
    "engaged",
    "enthusiastic",
    "focused",
    "hardworking",
    "independent",
    "inquisitive",
    "motivated",
    "organized",
    "positive",
    "reflective",
    "resilient",
    "thoughtful"
]

private let allowedEnglishFocusTags = [
    "Inferencing",
    "Literary Devices",
    "Text Structure",
    "Sentence Craft",
    "Punctuation",
    "Vocabulary"
]

private let allowedMathProficiencies = [
    "Understanding",
    "Fluency",
    "Problem Solving",
    "Reasoning"
]

private let allowedMathMindsetToggles = [
    "Growth mindset",
    "Perseveres with challenge",
    "Asks clarifying questions",
    "Explains/justifies reasoning",
    "Checks working carefully"
]

private let nextStepGoalsGeneral = [
    "ask clarifying questions",
    "expand elaborations (add detail)",
    "apply strategies independently",
    "reflect and set goals",
    "manage time effectively"
]

private let nextStepGoalsEnglish = [
    "improve inferencing",
    "use evidence from text",
    "edit for punctuation",
    "vary sentence openings",
    "use more descriptive vocabulary"
]

private let nextStepGoalsMath = [
    "check working and show steps",
    "justify reasoning",
    "apply problem-solving strategies",
    "build fluency with basic facts",
    "explain mathematical thinking"
]

private func assertCSVHeaders(_ headers: [String], required: [String]) throws {
    try assertCSVHeaderAliases(headers, required: required.map { .one($0) })
}

private func assertCSVHeaderAliases(_ headers: [String], required: [RequiredHeader]) throws {
    let normalizedHeaders = Set(headers.map(CSVParser.normalizeHeader))
    let missing = required.compactMap { entry -> String? in
        switch entry {
        case let .one(header):
            return normalizedHeaders.contains(CSVParser.normalizeHeader(header)) ? nil : header
        case let .any(aliases):
            return aliases.allSatisfy { !normalizedHeaders.contains(CSVParser.normalizeHeader($0)) } ? aliases[0] : nil
        }
    }
    if !missing.isEmpty {
        let suffix = missing.count == 1 ? "" : "s"
        throw ImportValidationError("The CSV file is missing required column\(suffix): \(missing.joined(separator: ", ")).")
    }
}

private func throwImportErrors(kind: String, validCount: Int, rejectedRows: [String]) throws {
    if validCount == 0 {
        throw ImportValidationError("No valid \(kind) imported. \(rejectedRows.prefix(3).joined(separator: " "))")
    }
    if !rejectedRows.isEmpty {
        let rowLabel = rejectedRows.count == 1 ? "row" : "rows"
        throw ImportValidationError("Import blocked. Fix \(rejectedRows.count) \(rowLabel) with missing or incorrect information before importing. \(rejectedRows.prefix(3).joined(separator: " "))")
    }
}

private func firstCSVValue(_ row: [String: String], aliases: [String]) -> String {
    aliases.lazy.map { CSVParser.value(in: row, matching: $0) }.first { !$0.isEmpty } ?? ""
}

private func parseCommaSeparated(_ value: String) -> [String] {
    value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
}

private func optionKey(_ value: String) -> String {
    value.lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func canonicalizeList(
    _ values: [String],
    allowedValues: [String],
    rowLabel: String,
    fieldLabel: String,
    rejectedRows: inout [String],
    maxCount: Int? = nil
) -> [String]? {
    if let maxCount, values.count > maxCount {
        let suffix = maxCount == 1 ? "" : "s"
        rejectedRows.append("\(rowLabel): \(fieldLabel) supports at most \(maxCount) value\(suffix)")
        return nil
    }

    let allowedByKey = Dictionary(uniqueKeysWithValues: allowedValues.map { (optionKey($0), $0) })
    var canonicalValues: [String] = []
    var seen = Set<String>()
    var invalidValues: [String] = []

    for value in values {
        let key = optionKey(value)
        guard let canonical = allowedByKey[key] else {
            invalidValues.append(value)
            continue
        }
        if !seen.contains(key) {
            seen.insert(key)
            canonicalValues.append(canonical)
        }
    }

    if !invalidValues.isEmpty {
        let suffix = invalidValues.count == 1 ? "" : "s"
        rejectedRows.append("\(rowLabel): \(fieldLabel) contains unrecognised value\(suffix): \(invalidValues.joined(separator: ", "))")
        return nil
    }

    return canonicalValues
}

private func validateResultFreeText(
    _ value: String,
    rowLabel: String,
    fieldLabel: String,
    rejectedRows: inout [String]
) -> Bool {
    guard value.count > maxResultFreeTextLength else { return true }
    rejectedRows.append("\(rowLabel): \(fieldLabel) must be \(maxResultFreeTextLength) characters or fewer")
    return false
}

private func studentKey(firstName: String, lastName: String, yearLevel: String) -> String {
    [
        firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        lastName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
        yearLevel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    ].joined(separator: "::")
}

private func normalizeYearLevel(_ value: String) -> StudentYearLevel? {
    let normalized = value.lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.range(of: #"^(year\s*)?5$|^y5$"#, options: .regularExpression) != nil { return .year5 }
    if normalized.range(of: #"^(year\s*)?6$|^y6$"#, options: .regularExpression) != nil { return .year6 }
    return nil
}

private func normalizeImportedGender(_ value: String) -> Gender?? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if normalized.isEmpty { return .some(nil) }
    if normalized == "m" || normalized == "male" { return .some(.male) }
    if normalized == "f" || normalized == "female" { return .some(.female) }
    return nil
}

private func canonicalAttitude(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else { return nil }
    return attitudeAdjectives.first { $0.lowercased() == normalized }
}

private func normalizeAchievementLevel(_ value: String) -> AchievementLevel? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.range(of: "beginning", options: [.caseInsensitive]) != nil { return .beginning }
    if normalized.range(of: "developing", options: [.caseInsensitive]) != nil { return .developing }
    if normalized.range(of: #"^at\s+standard$"#, options: [.regularExpression, .caseInsensitive]) != nil { return .atStandard }
    if normalized.range(of: "above", options: [.caseInsensitive]) != nil { return .aboveStandard }
    return AchievementLevel(rawValue: normalized)
}

private func findStudentForResult(
    roster: [Student],
    firstName: String,
    lastName: String,
    yearValue: String,
    rowLabel: String,
    rejectedRows: inout [String]
) -> Student? {
    let matches = roster.filter {
        $0.firstName.caseInsensitiveCompare(firstName) == .orderedSame
            && $0.lastName.caseInsensitiveCompare(lastName) == .orderedSame
    }
    if matches.count == 1 { return matches[0] }
    if matches.isEmpty {
        rejectedRows.append("\(rowLabel): student does not match this project")
        return nil
    }

    guard !yearValue.isEmpty, let yearLevel = normalizeYearLevel(yearValue) else {
        rejectedRows.append("\(rowLabel): student name is ambiguous; include Year Level")
        return nil
    }
    let byYear = matches.filter { $0.yearLevel == yearLevel }
    guard byYear.count == 1 else {
        rejectedRows.append("\(rowLabel): no matching student was found for \(firstName) \(lastName) in \(yearLevel.rawValue)")
        return nil
    }
    return byYear[0]
}

private func parseImportedReportContextField(
    _ raw: String,
    rowLabel: String,
    fieldLabel: String,
    rejectedRows: inout [String]
) -> String? {
    let normalized = normalizeReportContextField(raw)
    guard !normalized.isEmpty else { return "" }
    if raw.contains("\r") || raw.contains("\n") {
        rejectedRows.append("\(rowLabel): \(fieldLabel) must be a short phrase, not multiple lines.")
        return nil
    }
    if raw.range(of: #"\[[^\]]+\]|\{[^}]+\}"#, options: .regularExpression) != nil {
        rejectedRows.append("\(rowLabel): \(fieldLabel) must not contain template placeholders such as [context] or {Name}.")
        return nil
    }
    if normalized.count > 120 {
        rejectedRows.append("\(rowLabel): \(fieldLabel) must be 120 characters or fewer.")
        return nil
    }
    return normalized
}

private func normalizeReportContextField(_ value: String) -> String {
    let normalized = value
        .replacingOccurrences(of: #"[\t\r\n ]+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: #"[.!?;:]+$"#, with: "", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else { return "" }
    let marker = normalized.lowercased()
    if ["n/a", "na", "not applicable", "none", "null", "-"].contains(marker) || normalized == "\u{2014}" {
        return ""
    }
    return normalized
}

private func nextStepGoals(for subject: String) -> [String] {
    let normalized = subject.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized == "english" {
        return nextStepGoalsEnglish + nextStepGoalsGeneral
    }
    if normalized == "mathematics" || normalized == "maths" || normalized == "math" {
        return nextStepGoalsMath + nextStepGoalsGeneral
    }
    return nextStepGoalsGeneral
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
