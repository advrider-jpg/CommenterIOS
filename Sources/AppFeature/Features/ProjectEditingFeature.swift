import CommenterDomain
import ComposableArchitecture
extension AppFeature {
    func reduceProjectEditing(_ state: inout State, _ action: Action) -> Effect<Action> {
        switch action {
        case let .projectNameChanged(name):
            updateSelectedProject(&state) { $0.metadata.name = name }
            return .none

        case let .projectTermChanged(term):
            updateSelectedProject(&state) { $0.metadata.term = term }
            return .none

        case let .projectYearLevelChanged(yearLevel):
            updateSelectedProject(&state) { $0.metadata.yearLevel = yearLevel }
            return .none

        case let .useFirstNameOnlyChanged(enabled):
            updateSelectedProject(&state) { $0.metadata.useFirstNameOnly = enabled }
            return .none

        case .addStudentTapped:
            updateSelectedProject(&state) { project in
                project.roster.append(
                    Student(
                        id: nextManualStudentId(in: project),
                        firstName: "",
                        lastName: "",
                        yearLevel: .year5
                    )
                )
            }
            return .none

        case let .deleteStudentTapped(studentId):
            updateSelectedProject(&state) { project in
                project.roster.removeAll { $0.id == studentId }
                project.results.removeAll { $0.studentId == studentId }
                project.reports.removeAll { $0.studentId == studentId }
            }
            return .none

        case let .studentFirstNameChanged(studentId, value):
            updateStudent(&state, id: studentId) { $0.firstName = value }
            return .none

        case let .studentLastNameChanged(studentId, value):
            updateStudent(&state, id: studentId) { $0.lastName = value }
            return .none

        case let .studentYearLevelChanged(studentId, yearLevel):
            updateStudent(&state, id: studentId) { $0.yearLevel = yearLevel }
            return .none

        case let .subjectToggled(subject):
            updateSelectedProject(&state) { project in
                if project.metadata.selectedSubjects[subject] == nil {
                    project.metadata.selectedSubjects[subject] = SelectedSubject(name: subject, allStrandsSelected: true)
                } else {
                    project.metadata.selectedSubjects.removeValue(forKey: subject)
                    project.results.removeAll { $0.subject == subject }
                    project.reports.removeAll { $0.subject == subject }
                }
            }
            return .none

        case let .achievementLevelChanged(studentId, subject, level):
            updateResult(&state, studentId: studentId, subject: subject) { $0.achievementLevel = level }
            return .none

        case let .focusChanged(studentId, subject, focus):
            updateResult(&state, studentId: studentId, subject: subject) { $0.focusStrand = focus }
            return .none

        case let .reportManualEditChanged(studentId, subject, text):
            updateReport(&state, studentId: studentId, subject: subject) { $0.manualEdit = text }
            return .none

        case let .reportLockChanged(studentId, subject, isLocked):
            updateReport(&state, studentId: studentId, subject: subject) { $0.isLocked = isLocked }
            return .none

        default:
            return .none
        }
    }
}

private func nextManualStudentId(in project: Project) -> String {
    let existingIds = Set(project.roster.map(\.id))
    var counter = project.roster.count + 1
    while existingIds.contains("student-\(counter)") {
        counter += 1
    }
    return "student-\(counter)"
}
