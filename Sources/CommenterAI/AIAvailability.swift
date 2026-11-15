import FoundationModels

public enum AIAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)

    public var displayText: String {
        switch self {
        case .available: "Available on this iPhone"
        case let .unavailable(reason): reason
        }
    }
}

public struct AIClient: Sendable {
    public var availability: @Sendable () -> AIAvailability

    public init(availability: @escaping @Sendable () -> AIAvailability) {
        self.availability = availability
    }
}

extension AIClient {
    /// Apple's on-device model, named explicitly (PROJECT_RULES.md). No other model is ever used.
    public static let live = AIClient {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.deviceNotEligible): .unavailable(reason: "This iPhone doesn't support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled): .unavailable(reason: "Apple Intelligence is turned off in Settings.")
        case .unavailable(.modelNotReady): .unavailable(reason: "Apple Intelligence is still downloading.")
        case .unavailable: .unavailable(reason: "Apple Intelligence isn't available on this iPhone.")
        }
    }
}
