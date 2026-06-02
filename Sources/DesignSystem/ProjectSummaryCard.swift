import SwiftUI

public struct ProjectSummaryCard: View {
    private let name: String
    private let term: String
    private let revision: Int?

    public init(name: String, term: String, revision: Int?) {
        self.name = name
        self.term = term
        self.revision = revision
    }

    public var body: some View {
        NotebookCard(showsPaperclip: true) {
            HStack(alignment: .top, spacing: 12) {
                StatusIconBubble(systemImage: "folder", tone: .local)
                VStack(alignment: .leading, spacing: 7) {
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HStack(spacing: 6) {
                        Text(term)
                        if let revision {
                            Text("-")
                            Text("Revision \(revision)")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
