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

    public init(_ message: String?, systemImage: String, tone: WorkflowStatusTone = .neutral) {
        self.message = message
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        if let message, !message.isEmpty {
            Label(message, systemImage: systemImage)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
        }
    }

    private var color: Color {
        switch tone {
        case .neutral, .busy:
            return .secondary
        case .success:
            return .green
        case .warning:
            return .orange
        case .failure:
            return .red
        case .prepared:
            return .blue
        }
    }
}
