import Combine
import Foundation

public enum CommenterAppIntentDestination: String, Equatable, Sendable {
    case reportPreparation
}

@MainActor
public final class CommenterAppIntentRouter: ObservableObject {
    public static let shared = CommenterAppIntentRouter()

    @Published public private(set) var pendingDestination: CommenterAppIntentDestination?

    private init() {}

    public nonisolated static func request(_ destination: CommenterAppIntentDestination) async {
        await MainActor.run {
            shared.pendingDestination = destination
        }
    }

    public func consume(_ destination: CommenterAppIntentDestination) {
        guard pendingDestination == destination else { return }
        pendingDestination = nil
    }
}

#if canImport(AppIntents)
import AppIntents

@available(iOS 17.0, macOS 14.0, *)
public struct OpenReportPreparationIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Report Preparation"
    public static let description = IntentDescription("Opens Report Writer so the teacher can prepare approved reports in the app.")
    public static let openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await CommenterAppIntentRouter.request(.reportPreparation)
        return .result(dialog: "Opening report preparation in Report Writer. This shortcut cannot bypass readiness or teacher approval.")
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct CommenterShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenReportPreparationIntent(),
            phrases: [
                "Prepare reports in \(.applicationName)",
                "Open report preparation in \(.applicationName)"
            ],
            shortTitle: "Prepare Reports",
            systemImageName: "doc.badge.gearshape"
        )
    }
}
#endif
