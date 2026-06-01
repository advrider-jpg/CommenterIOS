import DesignSystem
import SwiftUI

struct OperationStatusView: View {
    let status: AppFeature.OperationStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case let .dirty(message):
            WorkflowStatusView(message, systemImage: "square.and.pencil", tone: .warning)
                .accessibilityIdentifier("operation-status-dirty")
        case let .busy(message):
            WorkflowStatusView(message, systemImage: "clock", tone: .busy)
                .accessibilityIdentifier("operation-status-busy")
        case let .saved(message):
            WorkflowStatusView(message, systemImage: "checkmark.circle", tone: .success)
                .accessibilityIdentifier("operation-status-saved")
        case let .prepared(message):
            WorkflowStatusView(message, systemImage: "doc.badge.gearshape", tone: .prepared)
                .accessibilityIdentifier("operation-status-prepared")
        case let .shared(message):
            WorkflowStatusView(message, systemImage: "square.and.arrow.up", tone: .success)
                .accessibilityIdentifier("operation-status-shared")
        case let .cancelled(message):
            WorkflowStatusView(message, systemImage: "xmark.circle", tone: .neutral)
                .accessibilityIdentifier("operation-status-cancelled")
        case let .failed(message):
            WorkflowStatusView(message, systemImage: "exclamationmark.triangle", tone: .failure)
                .accessibilityIdentifier("operation-status-failed")
        }
    }
}
