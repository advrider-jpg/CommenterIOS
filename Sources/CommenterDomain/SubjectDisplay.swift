import Foundation

public struct TeacherSubjectDescriptor: Equatable, Identifiable, Sendable {
    public var key: String
    public var displayName: String
    public var subtitle: String

    public var id: String { key }

    public init(key: String, displayName: String, subtitle: String) {
        self.key = key
        self.displayName = displayName
        self.subtitle = subtitle
    }
}

public let australianCurriculumSubjectOrder: [TeacherSubjectDescriptor] = [
    TeacherSubjectDescriptor(key: "English", displayName: "English", subtitle: "Include English comments in this report cycle."),
    TeacherSubjectDescriptor(key: "Mathematics", displayName: "Mathematics", subtitle: "Include Mathematics comments in this report cycle."),
    TeacherSubjectDescriptor(key: "Science", displayName: "Science", subtitle: "Include Science comments in this report cycle."),
    TeacherSubjectDescriptor(key: "HASS", displayName: "HASS", subtitle: "Include Humanities and Social Sciences comments."),
    TeacherSubjectDescriptor(key: "Health and P.E.", displayName: "Health and Physical Education", subtitle: "Include Health and Physical Education comments."),
    TeacherSubjectDescriptor(key: "The Arts", displayName: "The Arts", subtitle: "Include Arts comments; choose a specific focus when importing results."),
    TeacherSubjectDescriptor(key: "Technologies", displayName: "Technologies", subtitle: "Include Technologies comments; choose a specific focus when importing results.")
]

public func teacherSubjectKeysInCurriculumOrder() -> [String] {
    australianCurriculumSubjectOrder.map(\.key)
}

public func displaySubjectName(_ subjectKey: String) -> String {
    australianCurriculumSubjectOrder.first { $0.key == subjectKey }?.displayName ?? subjectKey
}

public func subjectSubtitle(_ subjectKey: String) -> String {
    australianCurriculumSubjectOrder.first { $0.key == subjectKey }?.subtitle ?? "Include this subject in the current report cycle."
}
