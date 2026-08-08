import Foundation

public struct SubjectResolution: Equatable, Sendable {
    public var uiSubject: String
    public var candidates: [String]
    public var selectedDataSubject: String?
    public var eligible: Bool
    public var reason: String?

    public init(
        uiSubject: String,
        candidates: [String],
        selectedDataSubject: String? = nil,
        eligible: Bool,
        reason: String? = nil
    ) {
        self.uiSubject = uiSubject
        self.candidates = candidates
        self.selectedDataSubject = selectedDataSubject
        self.eligible = eligible
        self.reason = reason
    }
}

private let subjectSynonyms: [String: [String]] = [
    "english": ["English"],
    "mathematics": ["Mathematics"],
    "maths": ["Mathematics"],
    "math": ["Mathematics"],
    "science": ["Science"],
    "humanities and social sciences": ["HASS", "Humanities and Social Sciences"],
    "hass": ["HASS", "Humanities and Social Sciences"],
    "health and physical education": ["Health and P.E.", "Health and Physical Education", "HPE"],
    "hpe": ["Health and P.E.", "Health and Physical Education", "HPE"],
    "the arts": ["Dance", "Drama", "Media Arts", "Music", "Visual Arts"],
    "arts": ["Dance", "Drama", "Media Arts", "Music", "Visual Arts"],
    "technologies": ["Design and Technologies", "Digital Technologies", "Technologies"],
    "technology": ["Design and Technologies", "Digital Technologies", "Technologies"],
    "languages": ["Languages"]
]

private let ambiguousAggregateSubjects: Set<String> = ["the arts", "technologies"]

private let componentStrandsByLearningFocus: [String: [String]] = [
    "english::language": [
        "Language for interacting with others",
        "Text structure and organisation",
        "Language for expressing and developing ideas",
        "Phonic and word knowledge"
    ],
    "english::literature": [
        "Literature and contexts",
        "Engaging with and responding to literature",
        "Examining literature",
        "Creating literature"
    ],
    "english::literacy": [
        "Texts in context",
        "Interacting with others",
        "Analysing, interpreting and evaluating",
        "Creating texts"
    ],
    "english::reading": [
        "Literature and contexts",
        "Engaging with and responding to literature",
        "Examining literature",
        "Texts in context",
        "Analysing, interpreting and evaluating",
        "Phonic and word knowledge"
    ],
    "english::writing": [
        "Text structure and organisation",
        "Language for expressing and developing ideas",
        "Creating literature",
        "Creating texts"
    ],
    "mathematics::number": ["Number", "Algebra"],
    "mathematics::measurement": ["Measurement", "Space"],
    "mathematics::statistics": ["Statistics", "Probability"],
    "science::science understanding": [
        "Biological sciences",
        "Chemical sciences",
        "Earth and space sciences",
        "Physical sciences"
    ],
    "science::science as a human endeavour": [
        "Nature and development of science",
        "Use and influence of science"
    ],
    "science::science inquiry skills": [
        "Questioning and predicting",
        "Planning and conducting",
        "Processing, modelling and analysing",
        "Evaluating",
        "Communicating"
    ],
    "health and physical education::personal, social and community health": [
        "Identities and change",
        "Interacting with others",
        "Making healthy and safe choices"
    ],
    "health and physical education::movement and physical activity": [
        "Moving our bodies",
        "Making active choices",
        "Learning through movement"
    ]
]

public func normalizeSubjectLabel(_ value: String) -> String {
    value
        .lowercased()
        .replacingOccurrences(of: "&", with: "and")
        .replacingOccurrences(of: ".", with: "")
        .replacingOccurrences(of: "\u{00a0}", with: " ")
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

public func componentStrandMatchesLearningFocus(
    uiSubject: String,
    learningFocus: String?,
    componentStrand: String?
) -> Bool {
    let normalizedFocus = normalizeSubjectLabel(learningFocus ?? "")
    guard !normalizedFocus.isEmpty else { return true }

    let normalizedComponent = normalizeSubjectLabel(componentStrand ?? "")
    guard !normalizedComponent.isEmpty else { return false }
    if normalizedComponent.contains(normalizedFocus) || normalizedFocus.contains(normalizedComponent) {
        return true
    }

    let normalizedSubject: String
    switch normalizeSubjectLabel(uiSubject) {
    case "math", "maths":
        normalizedSubject = "mathematics"
    case "hpe", "health and pe":
        normalizedSubject = "health and physical education"
    default:
        normalizedSubject = normalizeSubjectLabel(uiSubject)
    }
    let key = "\(normalizedSubject)::\(normalizedFocus)"
    return (componentStrandsByLearningFocus[key] ?? []).contains {
        normalizeSubjectLabel($0) == normalizedComponent
    }
}

public func getDatasetSubjects(_ data: CommentEngineData?) -> [String] {
    guard let data else { return [] }
    return Array(Set(data.componentBank.map(\.subject).filter { !$0.isEmpty }))
        .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

public func resolveSubjectCandidates(uiSubject: String, datasetSubjects: [String]) -> [String] {
    var normalizedDataset: [String: String] = [:]
    datasetSubjects.forEach { subject in
        normalizedDataset[normalizeSubjectLabel(subject)] = subject
    }
    let normalizedUi = normalizeSubjectLabel(uiSubject)
    if let exact = normalizedDataset[normalizedUi] {
        return [exact]
    }

    let matches = (subjectSynonyms[normalizedUi] ?? []).compactMap { candidate in
        normalizedDataset[normalizeSubjectLabel(candidate)]
    }
    return Array(Set(matches)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

public func resolveSubjectForGeneration(uiSubject: String, data: CommentEngineData, focusStrand: String? = nil) -> SubjectResolution {
    resolveSubjectForGeneration(
        uiSubject: uiSubject,
        datasetSubjects: getDatasetSubjects(data),
        focusStrand: focusStrand
    )
}

public func resolveSubjectForGeneration(
    uiSubject: String,
    datasetSubjects: [String],
    focusStrand: String? = nil
) -> SubjectResolution {
    let candidates = resolveSubjectCandidates(uiSubject: uiSubject, datasetSubjects: datasetSubjects)
    guard !candidates.isEmpty else {
        return SubjectResolution(
            uiSubject: uiSubject,
            candidates: [],
            eligible: false,
            reason: "Draft comments are not available for \(uiSubject) yet."
        )
    }

    let normalizedFocus = normalizeSubjectLabel(focusStrand ?? "")
    let focusedCandidate = normalizedFocus.isEmpty ? nil : candidates.first { normalizeSubjectLabel($0) == normalizedFocus }
    if let focusedCandidate {
        return SubjectResolution(
            uiSubject: uiSubject,
            candidates: [focusedCandidate],
            selectedDataSubject: focusedCandidate,
            eligible: true
        )
    }

    if candidates.count > 1 {
        return SubjectResolution(
            uiSubject: uiSubject,
            candidates: candidates,
            eligible: false,
            reason: "\(uiSubject) needs the specific subject chosen before draft comments can be created: \(candidates.joined(separator: ", "))."
        )
    }

    return SubjectResolution(
        uiSubject: uiSubject,
        candidates: candidates,
        selectedDataSubject: candidates[0],
        eligible: true
    )
}

public func subjectRequiresConcreteFocus(_ uiSubject: String) -> Bool {
    ambiguousAggregateSubjects.contains(normalizeSubjectLabel(uiSubject))
}

public func getConcreteFocusOptions(_ uiSubject: String) -> [String] {
    subjectSynonyms[normalizeSubjectLabel(uiSubject)] ?? []
}

public func getSubjectEligibilityMap(data: CommentEngineData?, uiSubjects: [String]) -> [String: SubjectResolution] {
    let datasetSubjects = getDatasetSubjects(data)
    return Dictionary(uniqueKeysWithValues: uiSubjects.map { subject in
        let candidates = resolveSubjectCandidates(uiSubject: subject, datasetSubjects: datasetSubjects)
        return (
            subject,
            SubjectResolution(
                uiSubject: subject,
                candidates: candidates,
                selectedDataSubject: candidates.count == 1 ? candidates[0] : nil,
                eligible: !candidates.isEmpty,
                reason: candidates.isEmpty ? "Draft comments are not available for \(subject) yet." : nil
            )
        )
    })
}

public func subjectMatchesUiSubject(datasetSubject: String, uiSubject: String, datasetSubjects: [String]) -> Bool {
    resolveSubjectCandidates(uiSubject: uiSubject, datasetSubjects: datasetSubjects)
        .contains { normalizeSubjectLabel($0) == normalizeSubjectLabel(datasetSubject) }
}
