import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum CommenterColors {
    public static let accent = Color(red: 0.12, green: 0.36, blue: 0.40)
    public static let accentSoft = Color(red: 0.86, green: 0.94, blue: 0.94)
    public static let success = Color(red: 0.16, green: 0.48, blue: 0.28)
    public static let warning = Color(red: 0.66, green: 0.42, blue: 0.08)
    public static let failure = Color(red: 0.70, green: 0.18, blue: 0.16)
    public static var surface: Color {
        #if canImport(UIKit)
        Color(UIColor.secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        Color(NSColor.windowBackgroundColor)
        #else
        Color.secondary.opacity(0.08)
        #endif
    }

    public static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(NSColor.controlBackgroundColor)
        #else
        Color.secondary.opacity(0.06)
        #endif
    }
}

public struct CommenterSectionHeader: View {
    private let title: String
    private let step: Int?
    private let detail: String?

    public init(_ title: String, step: Int? = nil, detail: String? = nil) {
        self.title = title
        self.step = step
        self.detail = detail
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let step {
                Text("\(step)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CommenterColors.accent))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .tracking(0.9)
                    .foregroundStyle(.secondary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .textCase(nil)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
    }
}

public struct StatusChip: View {
    private let text: String
    private let systemImage: String
    private let tone: WorkflowStatusTone

    public init(_ text: String, systemImage: String, tone: WorkflowStatusTone = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.14)))
            .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch tone {
        case .neutral, .busy:
            return .secondary
        case .success:
            return CommenterColors.success
        case .warning:
            return CommenterColors.warning
        case .failure:
            return CommenterColors.failure
        case .prepared:
            return CommenterColors.accent
        }
    }
}

public struct CommenterActionRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let isEnabled: Bool
    private let isDestructive: Bool
    private let showsChevron: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isEnabled: Bool = true,
        isDestructive: Bool = false,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(textColor)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .opacity(isEnabled ? 1 : 0.48)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var iconColor: Color {
        if !isEnabled { return .secondary }
        return isDestructive ? CommenterColors.failure : CommenterColors.accent
    }

    private var textColor: Color {
        if !isEnabled { return .secondary }
        return isDestructive ? CommenterColors.failure : .primary
    }
}

public struct CommenterEmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let primaryActionTitle: String?
    private let primaryAction: (() -> Void)?
    private let isActionDisabled: Bool

    public init(
        systemImage: String,
        title: String,
        message: String,
        primaryActionTitle: String? = nil,
        isActionDisabled: Bool = false,
        primaryAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.primaryActionTitle = primaryActionTitle
        self.primaryAction = primaryAction
        self.isActionDisabled = isActionDisabled
    }

    public var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .regular))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CommenterColors.accent)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let primaryActionTitle, let primaryAction {
                Button(action: primaryAction) {
                    Label(primaryActionTitle, systemImage: "arrow.right.circle")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(isActionDisabled)
                .accessibilityIdentifier("empty-state-primary-action")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
    }
}

public struct HashBlock: View {
    private let title: String
    private let hash: String

    public init(title: String, hash: String) {
        self.title = title
        self.hash = hash
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(groupedHash)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CommenterColors.accentSoft)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(hash)")
    }

    private var groupedHash: String {
        guard !hash.isEmpty else { return "Not available" }
        return stride(from: 0, to: hash.count, by: 8).map { index in
            let start = hash.index(hash.startIndex, offsetBy: index)
            let end = hash.index(start, offsetBy: min(8, hash.distance(from: start, to: hash.endIndex)))
            return String(hash[start..<end])
        }.joined(separator: " ")
    }
}
