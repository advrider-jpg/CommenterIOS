import SwiftUI

public enum WorkflowStatusTone: Equatable, Sendable {
    case neutral
    case busy
    case success
    case warning
    case failure
    case prepared
}

public struct WorkflowStatusView: View {
    private let message: String?
    private let systemImage: String
    private let tone: WorkflowStatusTone
    private let onDismiss: (() -> Void)?

    public init(
        _ message: String?,
        systemImage: String,
        tone: WorkflowStatusTone = .neutral,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if let message, !message.isEmpty {
            NotebookCard(showsPerforation: false, showsStack: false) {
                HStack(alignment: .top, spacing: 10) {
                    StatusIconBubble(systemImage: systemImage, tone: tone.stationeryTone)
                    Text(message)
                        .font(.subheadline.weight(tone == .failure ? .semibold : .regular))
                        .foregroundStyle(tone.stationeryTone.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if let onDismiss {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                        }
                        .buttonStyle(.plain)
                        .frame(
                            minWidth: CommenterStationeryTheme.Metrics.minimumTapTarget,
                            minHeight: CommenterStationeryTheme.Metrics.minimumTapTarget
                        )
                        .accessibilityLabel("Dismiss status message")
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
