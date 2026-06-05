import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum CommenterColors {
    public static let accent = CommenterStationeryTheme.Colors.actionBlue
    public static let accentSoft = CommenterStationeryTheme.Colors.actionBlueSoft
    public static let success = CommenterStationeryTheme.Colors.localGreen
    public static let warning = CommenterStationeryTheme.Colors.attentionOrange
    public static let failure = CommenterStationeryTheme.Colors.destructiveRed
    public static var surface: Color {
        CommenterStationeryTheme.Colors.paperSurface
    }

    public static var groupedBackground: Color {
        CommenterStationeryTheme.Colors.paperBackground
    }
}

public extension View {
    @ViewBuilder
    func commenterGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.automatic)
        #endif
    }

    @ViewBuilder
    func commenterLargeNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func commenterInlineNavigationTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func commenterWordsTextInput() -> some View {
        #if os(iOS)
        self.textInputAutocapitalization(.words)
        #else
        self
        #endif
    }

    @ViewBuilder
    func commenterReportTextInput() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
        #else
        self
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
                    .foregroundStyle(CommenterStationeryTheme.Colors.localGreen)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CommenterStationeryTheme.Colors.localGreenSoft))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                TapeLabel(title)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .textCase(nil)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .padding(.top, 4)
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
        StationeryStatusChip(text, systemImage: systemImage, tone: tone.stationeryTone)
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
        StationeryActionRow(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tone: isDestructive ? .failure : .action,
            isEnabled: isEnabled,
            showsChevron: showsChevron
        )
        .accessibilityAddTraits(.isButton)
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
        StationeryEmptyState(
            systemImage: systemImage,
            title: title,
            message: message,
            primaryActionTitle: primaryActionTitle,
            isActionDisabled: isActionDisabled,
            primaryAction: primaryAction
        )
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
                        .fill(CommenterStationeryTheme.Colors.actionBlueSoft)
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
