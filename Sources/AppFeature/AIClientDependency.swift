import CommenterAI
import ComposableArchitecture

extension AIClient: DependencyKey {
    public static let liveValue = AIClient.live
    public static let testValue = AIClient { .unavailable(reason: "Apple Intelligence isn't available on this iPhone.") }
}

extension DependencyValues {
    public var aiClient: AIClient {
        get { self[AIClient.self] }
        set { self[AIClient.self] = newValue }
    }
}
