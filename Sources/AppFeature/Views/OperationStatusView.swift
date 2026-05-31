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
        case let .busy(message):
            WorkflowStatusView(message, systemImage: "clock", tone: .busy)
        case let .saved(message):
            WorkflowStatusView(message, systemImage: "checkmark.circle", tone: .success)
        case let .prepared(message):
            WorkflowStatusView(message, systemImage: "doc.badge.gearshape", tone: .prepared)
        case let .cancelled(message):
            WorkflowStatusView(message, systemImage: "xmark.circle", tone: .neutral)
        case let .failed(message):
            WorkflowStatusView(message, systemImage: "exclamationmark.triangle", tone: .failure)
        }
    }
}
