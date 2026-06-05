#if canImport(FoundationModels)
import CommenterDomain
import FoundationModels

@available(iOS 26.0, macOS 26.0, *)
public enum FoundationModelAvailabilityChecker {
    public static func current() -> AIModelAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        case .unavailable(_):
            return .unavailable(.unknown)
        }
    }
}
#endif
