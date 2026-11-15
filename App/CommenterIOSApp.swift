import AppFeature
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct CommenterIOSApp: App {
    init() {
        #if canImport(UIKit)
        if ProcessInfo.processInfo.arguments.contains("-UITestMode")
            || ProcessInfo.processInfo.environment["UITEST_DISABLE_ANIMATIONS"] == "1" {
            UIView.setAnimationsEnabled(false)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
        }
    }
}
