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
        VStack(alignment: .leading, spacing: 5) {
            Text(name)
                .font(.body.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            HStack(spacing: 6) {
                Text(term)
                if let revision {
                    Text("-")
                    Text("Revision \(revision)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
