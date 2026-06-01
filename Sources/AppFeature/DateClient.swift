import ComposableArchitecture
import Foundation

public struct DateClient: Sendable {
    public var nowMilliseconds: @Sendable () -> Int64

    public init(nowMilliseconds: @escaping @Sendable () -> Int64) {
        self.nowMilliseconds = nowMilliseconds
    }
}

extension DateClient: DependencyKey {
    public static let liveValue = DateClient {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }

    public static let testValue = DateClient {
        0
    }
}

public extension DependencyValues {
    var dateClient: DateClient {
        get { self[DateClient.self] }
        set { self[DateClient.self] = newValue }
    }
}
