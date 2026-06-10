import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 17.0, macOS 14.0, *)
public struct OpenOnDeviceAIReviewQueueIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open AI Review Queue"
    public static var description = IntentDescription("Opens Report Writer so the teacher can review pending AI draft previews in the app.")
    public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Open Report Writer to review AI draft previews. This shortcut does not generate, approve, export, or share report text.")
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct OpenReportPreparationIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Report Preparation"
    public static var description = IntentDescription("Opens Report Writer so the teacher can prepare approved reports in the app.")
    public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Open Report Writer to prepare approved reports. This shortcut cannot bypass readiness or teacher approval.")
    }
}

@available(iOS 17.0, macOS 14.0, *)
public struct CommenterShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenOnDeviceAIReviewQueueIntent(),
            phrases: [
                "Open AI review in \(.applicationName)",
                "Review AI drafts in \(.applicationName)"
            ],
            shortTitle: "AI Review",
            systemImageName: "person.crop.circle.badge.checkmark"
        )
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
