import Foundation

public enum AppPrivacyPolicy {
    public static func url(bundle: Bundle = .main) -> URL? {
        guard let value = bundle.object(forInfoDictionaryKey: "REPORT_WRITER_PRIVACY_POLICY_URL") as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("https://"), let url = URL(string: trimmed) else {
            return nil
        }
        return url
    }
}
