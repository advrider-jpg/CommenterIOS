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
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.headline)
            Text(term)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let revision {
                Text("Revision \(revision)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
