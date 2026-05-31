import ComposableArchitecture
import SwiftUI

public struct AppEntryView: View {
    public init() {}

    public var body: some View {
        AppView(
            store: Store(initialState: AppFeature.State()) {
                AppFeature()
            }
        )
    }
}
