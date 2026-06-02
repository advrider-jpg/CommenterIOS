import SwiftUI

public struct UnavailableFeatureNotice: View {
    private let title: String
    private let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public var body: some View {
        NotebookCard(showsPaperclip: true) {
            HStack(alignment: .top, spacing: 12) {
                StatusIconBubble(systemImage: "exclamationmark.triangle", tone: .warning)
                VStack(alignment: .leading, spacing: 8) {
                    TapeLabel(title, tone: .warning)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
