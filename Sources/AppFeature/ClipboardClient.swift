import ComposableArchitecture
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ClipboardClient: Sendable {
    public var copy: @Sendable (_ text: String) async throws -> Void

    public init(copy: @escaping @Sendable (_ text: String) async throws -> Void) {
        self.copy = copy
    }
}

extension ClipboardClient: DependencyKey {
    public static let liveValue = ClipboardClient { text in
        #if canImport(UIKit)
        await MainActor.run {
            UIPasteboard.general.string = text
        }
        #elseif canImport(AppKit)
        try await MainActor.run {
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(text, forType: .string) else {
                throw ClipboardError.unavailable
            }
        }
        #else
        _ = text
        throw ClipboardError.unavailable
        #endif
    }

    public static let testValue = ClipboardClient { _ in }
}

public enum ClipboardError: LocalizedError, Equatable {
    case unavailable

    public var errorDescription: String? {
        "Clipboard is unavailable in this environment."
    }
}

public extension DependencyValues {
    var clipboardClient: ClipboardClient {
        get { self[ClipboardClient.self] }
        set { self[ClipboardClient.self] = newValue }
    }
}
