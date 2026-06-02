import SwiftUI

public enum CommenterStationeryTheme {
    public enum Colors {
        public static let paperBackground = Color(red: 0.965, green: 0.937, blue: 0.875)
        public static let paperSurface = Color(red: 1.000, green: 0.976, blue: 0.925)
        public static let paperSurfaceDeep = Color(red: 0.957, green: 0.910, blue: 0.827)
        public static let paperLine = Color(red: 0.463, green: 0.392, blue: 0.282).opacity(0.22)
        public static let ink = Color(red: 0.090, green: 0.078, blue: 0.067)
        public static let secondaryInk = Color(red: 0.373, green: 0.341, blue: 0.302)
        public static let mutedInk = Color(red: 0.459, green: 0.427, blue: 0.380)
        public static let tape = Color(red: 0.918, green: 0.843, blue: 0.678)
        public static let tapeLight = Color(red: 0.957, green: 0.894, blue: 0.773)
        public static let localGreen = Color(red: 0.231, green: 0.529, blue: 0.314)
        public static let localGreenSoft = Color(red: 0.894, green: 0.945, blue: 0.867)
        public static let actionBlue = Color(red: 0.145, green: 0.427, blue: 0.784)
        public static let actionBlueSoft = Color(red: 0.902, green: 0.933, blue: 0.973)
        public static let attentionOrange = Color(red: 0.847, green: 0.475, blue: 0.173)
        public static let attentionOrangeSoft = Color(red: 0.980, green: 0.906, blue: 0.824)
        public static let gold = Color(red: 0.843, green: 0.639, blue: 0.129)
        public static let goldSoft = Color(red: 0.969, green: 0.929, blue: 0.784)
        public static let destructiveRed = Color(red: 0.725, green: 0.294, blue: 0.227)
        public static let destructiveRedSoft = Color(red: 0.965, green: 0.867, blue: 0.839)
    }

    public enum Metrics {
        public static let screenHorizontalPadding: CGFloat = 20
        public static let sectionSpacing: CGFloat = 18
        public static let cardPadding: CGFloat = 18
        public static let cardCornerRadius: CGFloat = 12
        public static let rowVerticalPadding: CGFloat = 14
        public static let rowHorizontalPadding: CGFloat = 16
        public static let minimumTapTarget: CGFloat = 44
        public static let perforationWidth: CGFloat = 18
    }

    public enum Typography {
        public static let largePageTitle = Font.system(.largeTitle, design: .serif).weight(.semibold)
        public static let compactPageTitle = Font.system(.title, design: .serif).weight(.semibold)
        public static let handwritten = Font.callout.italic()
        public static let tapeLabel = Font.callout.weight(.semibold)
    }
}

public enum StationeryTone: Equatable, Sendable {
    case neutral
    case local
    case success
    case warning
    case failure
    case prepared
    case action

    public var color: Color {
        switch self {
        case .neutral:
            return CommenterStationeryTheme.Colors.secondaryInk
        case .local, .success:
            return CommenterStationeryTheme.Colors.localGreen
        case .warning:
            return CommenterStationeryTheme.Colors.attentionOrange
        case .failure:
            return CommenterStationeryTheme.Colors.destructiveRed
        case .prepared, .action:
            return CommenterStationeryTheme.Colors.actionBlue
        }
    }

    public var softColor: Color {
        switch self {
        case .neutral:
            return CommenterStationeryTheme.Colors.paperSurfaceDeep
        case .local, .success:
            return CommenterStationeryTheme.Colors.localGreenSoft
        case .warning:
            return CommenterStationeryTheme.Colors.attentionOrangeSoft
        case .failure:
            return CommenterStationeryTheme.Colors.destructiveRedSoft
        case .prepared, .action:
            return CommenterStationeryTheme.Colors.actionBlueSoft
        }
    }
}

public extension WorkflowStatusTone {
    var stationeryTone: StationeryTone {
        switch self {
        case .neutral, .busy:
            return .neutral
        case .success:
            return .success
        case .warning:
            return .warning
        case .failure:
            return .failure
        case .prepared:
            return .prepared
        }
    }
}

public struct StationeryScreen<Content: View>: View {
    private let showsDeskFooter: Bool
    private let scrollAccessibilityIdentifier: String?
    private let content: Content

    public init(
        showsDeskFooter: Bool = true,
        scrollAccessibilityIdentifier: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.showsDeskFooter = showsDeskFooter
        self.scrollAccessibilityIdentifier = scrollAccessibilityIdentifier
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            CommenterStationeryTheme.Colors.paperBackground
                .ignoresSafeArea()
                .overlay(StationeryPaperTexture().ignoresSafeArea())
            ScrollView {
                VStack(alignment: .leading, spacing: CommenterStationeryTheme.Metrics.sectionSpacing) {
                    content
                }
                .padding(.horizontal, CommenterStationeryTheme.Metrics.screenHorizontalPadding)
                .padding(.top, 18)
                .padding(.bottom, showsDeskFooter ? 96 : 32)
            }
            .scrollIndicators(.visible)
            .stationeryAccessibilityIdentifier(scrollAccessibilityIdentifier)
            if showsDeskFooter {
                DeskEdgeDecoration()
                    .accessibilityHidden(true)
            }
        }
    }
}

public struct StationeryPageHeader: View {
    private let title: String
    private let subtitle: String?
    private let leadingSystemImage: String?
    private let trailingSystemImage: String?
    private let trailingAccessibilityLabel: String?

    public init(
        _ title: String,
        subtitle: String? = nil,
        leadingSystemImage: String? = nil,
        trailingSystemImage: String? = nil,
        trailingAccessibilityLabel: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.leadingSystemImage = leadingSystemImage
        self.trailingSystemImage = trailingSystemImage
        self.trailingAccessibilityLabel = trailingAccessibilityLabel
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let leadingSystemImage {
                StatusIconBubble(systemImage: leadingSystemImage, tone: .local)
                    .accessibilityHidden(false)
                    .accessibilityLabel(title)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(CommenterStationeryTheme.Typography.largePageTitle)
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    HandwrittenAnnotation(subtitle)
                }
            }
            Spacer(minLength: 8)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    .frame(width: 42, height: 42)
                    .background(
                        CommenterStationeryTheme.Colors.paperSurface,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                    .accessibilityLabel(trailingAccessibilityLabel ?? "Screen action")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

public struct HandwrittenAnnotation: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        Text(text)
            .font(CommenterStationeryTheme.Typography.handwritten)
            .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
            .rotationEffect(.degrees(-2))
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(CommenterStationeryTheme.Colors.mutedInk.opacity(0.25))
                    .frame(height: 1.5)
                    .offset(y: 4)
                    .rotationEffect(.degrees(1))
                    .accessibilityHidden(true)
            }
            .accessibilityLabel(text)
    }
}

public struct TapeLabel: View {
    private let title: String
    private let tone: StationeryTone

    public init(_ title: String, tone: StationeryTone = .neutral) {
        self.title = title
        self.tone = tone
    }

    public var body: some View {
        Text(title)
            .font(CommenterStationeryTheme.Typography.tapeLabel)
            .foregroundStyle(CommenterStationeryTheme.Colors.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(tapeColor, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .rotationEffect(.degrees(-1.5))
            .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
            .accessibilityAddTraits(.isHeader)
    }

    private var tapeColor: Color {
        switch tone {
        case .local, .success:
            return CommenterStationeryTheme.Colors.localGreenSoft
        case .warning:
            return CommenterStationeryTheme.Colors.attentionOrangeSoft
        case .failure:
            return CommenterStationeryTheme.Colors.destructiveRedSoft
        case .prepared, .action:
            return CommenterStationeryTheme.Colors.actionBlueSoft
        case .neutral:
            return CommenterStationeryTheme.Colors.tape
        }
    }
}

public struct NotebookCard<Content: View>: View {
    private let showsPerforation: Bool
    private let showsPaperclip: Bool
    private let showsStack: Bool
    private let content: Content

    public init(
        showsPerforation: Bool = true,
        showsPaperclip: Bool = false,
        showsStack: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.showsPerforation = showsPerforation
        self.showsPaperclip = showsPaperclip
        self.showsStack = showsStack
        self.content = content()
    }

    public var body: some View {
        PaperStack(showsBacking: showsStack) {
            HStack(spacing: 0) {
                if showsPerforation {
                    PerforatedPaperEdge()
                        .frame(width: CommenterStationeryTheme.Metrics.perforationWidth)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CommenterStationeryTheme.Metrics.cardPadding)
            }
            .background(
                CommenterStationeryTheme.Colors.paperSurface,
                in: RoundedRectangle(cornerRadius: CommenterStationeryTheme.Metrics.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CommenterStationeryTheme.Metrics.cardCornerRadius, style: .continuous)
                    .stroke(CommenterStationeryTheme.Colors.paperLine, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 7)
            .overlay(alignment: .topLeading) {
                if showsPaperclip {
                    PaperclipDecoration()
                        .offset(x: 2, y: -18)
                        .accessibilityHidden(true)
                }
            }
        }
    }
}

public struct PaperStack<Content: View>: View {
    private let showsBacking: Bool
    private let content: Content

    public init(showsBacking: Bool = true, @ViewBuilder content: () -> Content) {
        self.showsBacking = showsBacking
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if showsBacking {
                RoundedRectangle(cornerRadius: CommenterStationeryTheme.Metrics.cardCornerRadius, style: .continuous)
                    .fill(CommenterStationeryTheme.Colors.paperSurfaceDeep)
                    .offset(x: 6, y: 7)
                    .rotationEffect(.degrees(0.7))
                    .accessibilityHidden(true)
            }
            content
        }
    }
}

public struct PerforatedPaperEdge: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let count = max(4, Int(proxy.size.height / 28))
            VStack(spacing: 13) {
                ForEach(0..<count, id: \.self) { _ in
                    Circle()
                        .fill(CommenterStationeryTheme.Colors.paperBackground)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(CommenterStationeryTheme.Colors.paperLine, lineWidth: 1))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .padding(.top, 10)
        }
    }
}

public struct PaperclipDecoration: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(CommenterStationeryTheme.Colors.gold, lineWidth: 3)
            .frame(width: 19, height: 44)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CommenterStationeryTheme.Colors.gold.opacity(0.55), lineWidth: 2)
                    .padding(5)
            }
            .rotationEffect(.degrees(12))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
            .allowsHitTesting(false)
    }
}

public struct StationeryStatusChip: View {
    private let text: String
    private let systemImage: String?
    private let tone: StationeryTone

    public init(_ text: String, systemImage: String? = nil, tone: StationeryTone = .neutral) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        Label {
            Text(text)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            } else {
                EmptyView()
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tone.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tone.softColor))
        .accessibilityElement(children: .combine)
    }
}

public struct StatusIconBubble: View {
    private let systemImage: String
    private let tone: StationeryTone

    public init(systemImage: String, tone: StationeryTone = .neutral) {
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tone.color)
            .frame(width: 42, height: 42)
            .background(Circle().fill(tone.softColor))
            .accessibilityHidden(true)
    }
}

public struct StationerySearchBar: View {
    private let prompt: String
    @Binding private var text: String

    public init(_ prompt: String = "Search", text: Binding<String>) {
        self.prompt = prompt
        self._text = text
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                .accessibilityHidden(true)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(CommenterStationeryTheme.Colors.mutedInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: CommenterStationeryTheme.Metrics.minimumTapTarget)
        .background(
            CommenterStationeryTheme.Colors.paperSurface,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CommenterStationeryTheme.Colors.paperLine, lineWidth: 1)
        }
    }
}

public struct StationeryActionRow: View {
    private let title: String
    private let subtitle: String?
    private let systemImage: String
    private let tone: StationeryTone
    private let isEnabled: Bool
    private let trailing: String?
    private let showsChevron: Bool

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        tone: StationeryTone = .action,
        isEnabled: Bool = true,
        trailing: String? = nil,
        showsChevron: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.tone = tone
        self.isEnabled = isEnabled
        self.trailing = trailing
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusIconBubble(systemImage: systemImage, tone: isEnabled ? tone : .neutral)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isEnabled ? CommenterStationeryTheme.Colors.ink : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let trailing, !trailing.isEmpty {
                StationeryStatusChip(trailing, tone: tone)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: CommenterStationeryTheme.Metrics.minimumTapTarget)
        .opacity(isEnabled ? 1 : 0.48)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

public struct StationeryFormRow<Content: View>: View {
    private let title: String
    private let detail: String?
    private let content: Content

    public init(_ title: String, detail: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 10)
                content
            }
            Divider()
                .overlay(CommenterStationeryTheme.Colors.paperLine)
        }
        .padding(.vertical, CommenterStationeryTheme.Metrics.rowVerticalPadding)
        .accessibilityElement(children: .contain)
    }
}

public struct StationeryMetric: View {
    private let value: String
    private let label: String
    private let systemImage: String?
    private let tone: StationeryTone

    public init(value: String, label: String, systemImage: String? = nil, tone: StationeryTone = .neutral) {
        self.value = value
        self.label = label
        self.systemImage = systemImage
        self.tone = tone
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let systemImage {
                StatusIconBubble(systemImage: systemImage, tone: tone)
            }
            Text(value)
                .font(.title2.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(14)
        .background(tone.softColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

public struct StationeryEmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let primaryActionTitle: String?
    private let isActionDisabled: Bool
    private let primaryAction: (() -> Void)?

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
        self.isActionDisabled = isActionDisabled
        self.primaryAction = primaryAction
    }

    public var body: some View {
        NotebookCard(showsPaperclip: true) {
            VStack(spacing: 14) {
                StatusIconBubble(systemImage: systemImage, tone: .action)
                VStack(spacing: 6) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(CommenterStationeryTheme.Colors.secondaryInk)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let primaryActionTitle, let primaryAction {
                    Button(action: primaryAction) {
                        Label(primaryActionTitle, systemImage: "arrow.right.circle")
                            .font(.body.weight(.semibold))
                            .frame(minHeight: CommenterStationeryTheme.Metrics.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CommenterStationeryTheme.Colors.actionBlue)
                    .disabled(isActionDisabled)
                    .accessibilityIdentifier("empty-state-primary-action")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .contain)
    }
}

public struct WorkflowTimelineItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let detail: String?
    public let systemImage: String
    public let tone: StationeryTone

    public init(id: String, title: String, detail: String? = nil, systemImage: String, tone: StationeryTone = .neutral) {
        self.id = id
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.tone = tone
    }
}

public struct WorkflowTimeline: View {
    private let items: [WorkflowTimelineItem]

    public init(items: [WorkflowTimelineItem]) {
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { pair in
                let index = pair.offset
                let item = pair.element
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        StatusIconBubble(systemImage: item.systemImage, tone: item.tone)
                        if index < items.count - 1 {
                            Rectangle()
                                .fill(CommenterStationeryTheme.Colors.paperLine)
                                .frame(width: 2, minHeight: 24)
                                .accessibilityHidden(true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(CommenterStationeryTheme.Colors.ink)
                        if let detail = item.detail, !detail.isEmpty {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, 3)
                    Spacer(minLength: 0)
                }
                .padding(.bottom, index < items.count - 1 ? 10 : 0)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

public struct StationeryPaperTexture: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            for x in stride(from: CGFloat.zero, through: size.width, by: 23) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(.brown.opacity(0.015)), lineWidth: 0.5)
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: 23) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(.brown.opacity(0.018)), lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

public struct DeskEdgeDecoration: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.78, green: 0.58, blue: 0.34).opacity(0.0),
                            Color(red: 0.78, green: 0.58, blue: 0.34).opacity(0.82)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 92)
            HStack(alignment: .bottom) {
                NotebookDoodle()
                    .frame(width: 130, height: 62)
                Spacer()
                CoffeeMugDoodle()
                    .frame(width: 92, height: 82)
            }
            .padding(.horizontal, 12)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct NotebookDoodle: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(.white.opacity(0.62))
                .rotationEffect(.degrees(-8))
            Capsule()
                .fill(CommenterStationeryTheme.Colors.gold)
                .frame(width: 86, height: 9)
                .rotationEffect(.degrees(-18))
                .offset(x: 50, y: -22)
            RoundedRectangle(cornerRadius: 3)
                .fill(CommenterStationeryTheme.Colors.paperSurfaceDeep)
                .frame(width: 38, height: 18)
                .rotationEffect(.degrees(-8))
                .offset(x: 90, y: -8)
        }
    }
}

private struct CoffeeMugDoodle: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.36, green: 0.55, blue: 0.53))
            Circle()
                .fill(Color(red: 0.13, green: 0.08, blue: 0.04))
                .padding(16)
            Circle()
                .stroke(CommenterStationeryTheme.Colors.paperSurface, lineWidth: 4)
                .padding(5)
        }
    }
}

private struct StationeryAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private extension View {
    func stationeryAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(StationeryAccessibilityIdentifier(identifier: identifier))
    }
}
