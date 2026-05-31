import Foundation

public enum CSVTemplateKind: Equatable, Sendable {
    case roster
    case achievementResults
}
public struct CSVTemplateDocument: Equatable, Sendable {
    public var filename: String
    public var mimeType: String
    public var text: String

    public init(filename: String, mimeType: String, text: String) {
        self.filename = filename
        self.mimeType = mimeType
        self.text = text
    }
}

public enum CSVTemplateError: LocalizedError, Equatable {
    case unsupportedFormat(ImportExportFormat)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            return "\(format.rawValue.uppercased()) template export is unavailable here. CSV template serialization supports CSV only."
        }
    }
}

public enum CSVTemplates {
    public static let rosterFilename = "commenter_roster_template.csv"
    public static let achievementResultsFilename = "commenter_results_template.csv"
    public static let csvMimeType = "text/csv;charset=utf-8"

    public static let rosterHeaders = [
        "First Name",
        "Last Name",
        "Year Level",
        "Gender",
        "Attitude",
        "Private Teacher Note"
    ]

    public static let achievementResultsHeaders = [
        "First Name",
        "Last Name",
        "Year Level",
        "Subject",
        "Achievement Level",
        "Focus",
        "Evidence",
        "Text Type",
        "Learning Context",
        "Optional Report Note",
        "English Focus Areas",
        "Mathematics Proficiency Areas",
        "Mathematics Learning Habits",
        "Next Step Goals"
    ]

    public static func rosterTemplateRows() -> [[String: String]] {
        [
            [
                "First Name": "John",
                "Last Name": "Doe",
                "Year Level": "Year 5",
                "Gender": "Male",
                "Attitude": "enthusiastic",
                "Private Teacher Note": "Private note; not included in reports"
            ],
            [
                "First Name": "Jane",
                "Last Name": "Smith",
                "Year Level": "Year 6",
                "Gender": "Female",
                "Attitude": "diligent",
                "Private Teacher Note": ""
            ]
        ]
    }

    public static func achievementResultsTemplateRows() -> [[String: String]] {
        [
            [
                "First Name": "John",
                "Last Name": "Doe",
                "Year Level": "Year 5",
                "Subject": "Mathematics",
                "Achievement Level": "At Standard",
                "Focus": "Number",
                "Evidence": "solved multi-step problems with working shown",
                "Text Type": "",
                "Learning Context": "",
                "Optional Report Note": "May appear in the report",
                "English Focus Areas": "",
                "Mathematics Proficiency Areas": "Understanding, Fluency",
                "Mathematics Learning Habits": "Growth mindset, Checks working carefully",
                "Next Step Goals": "check working and show steps"
            ],
            [
                "First Name": "Jane",
                "Last Name": "Smith",
                "Year Level": "Year 6",
                "Subject": "English",
                "Achievement Level": "Above Standard",
                "Focus": "Reading",
                "Evidence": "used inferencing to identify themes",
                "Text Type": "persuasive text",
                "Learning Context": "advertising unit",
                "Optional Report Note": "",
                "English Focus Areas": "Inferencing, Text Structure",
                "Mathematics Proficiency Areas": "",
                "Mathematics Learning Habits": "",
                "Next Step Goals": "vary sentence openings"
            ],
            [
                "First Name": "Ari",
                "Last Name": "Kaur",
                "Year Level": "Year 5",
                "Subject": "The Arts",
                "Achievement Level": "At Standard",
                "Focus": "Music",
                "Evidence": "kept a steady rhythm",
                "Text Type": "performance",
                "Learning Context": "rhythm task",
                "Optional Report Note": "For The Arts or Technologies, keep the main subject in Subject and put the specific subject, such as Music, in Focus.",
                "English Focus Areas": "",
                "Mathematics Proficiency Areas": "",
                "Mathematics Learning Habits": "",
                "Next Step Goals": ""
            ]
        ]
    }

    public static func rosterTemplateCSV() -> String {
        serializeCSV(rows: rosterTemplateRows(), headers: rosterHeaders)
    }

    public static func achievementResultsTemplateCSV() -> String {
        serializeCSV(rows: achievementResultsTemplateRows(), headers: achievementResultsHeaders)
    }

    public static func templateDocument(kind: CSVTemplateKind, format: ImportExportFormat = .csv) throws -> CSVTemplateDocument {
        guard format == .csv else {
            throw CSVTemplateError.unsupportedFormat(format)
        }

        switch kind {
        case .roster:
            return CSVTemplateDocument(filename: rosterFilename, mimeType: csvMimeType, text: rosterTemplateCSV())
        case .achievementResults:
            return CSVTemplateDocument(
                filename: achievementResultsFilename,
                mimeType: csvMimeType,
                text: achievementResultsTemplateCSV()
            )
        }
    }

    private static func serializeCSV(rows: [[String: String]], headers: [String]) -> String {
        guard !rows.isEmpty else { return "" }
        let lines = [headers.map(escapeCell).joined(separator: ",")] + rows.map { row in
            headers.map { escapeCell(row[$0] ?? "") }.joined(separator: ",")
        }
        return lines.joined(separator: "\r\n")
    }

    private static func escapeCell(_ value: String) -> String {
        let guarded = value.range(of: #"^\s*[=+\-@]"#, options: .regularExpression) == nil ? value : "'\(value)"
        let escaped = guarded.replacingOccurrences(of: "\"", with: "\"\"")
        return escaped.range(of: #"[",\r\n]"#, options: .regularExpression) == nil ? escaped : "\"\(escaped)\""
    }
}
