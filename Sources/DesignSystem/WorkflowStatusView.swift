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
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(color)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss status message")
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
        }
    }

    private var color: Color {
        switch tone {
        case .neutral, .busy:
            return .secondary
        case .success:
            return CommenterColors.success
        case .warning:
            return CommenterColors.warning
        case .failure:
            return CommenterColors.failure
        case .prepared:
            return CommenterColors.accent
        }
    }
}
