import CommenterAI
import ComposableArchitecture

private enum AIClientKey: DependencyKey {
    static let liveValue = AIClient.live
    static let testValue = AIClient.unavailable
}

public extension DependencyValues {
    var aiClient: AIClient {
        get { self[AIClientKey.self] }
        set { self[AIClientKey.self] = newValue }
    }
}
