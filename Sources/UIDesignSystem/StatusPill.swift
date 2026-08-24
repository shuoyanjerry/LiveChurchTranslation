import SwiftUI

public enum StatusPillIndicatorStyle: Sendable {
    case dot
    case pulse
    case progress
}

public struct StatusPill: View {
    private let text: String
    private let color: Color
    private let indicatorStyle: StatusPillIndicatorStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        text: String,
        color: Color,
        indicatorStyle: StatusPillIndicatorStyle = .dot
    ) {
        self.text = text
        self.color = color
        self.indicatorStyle = indicatorStyle
    }

    public var body: some View {
        HStack(spacing: 8) {
            indicator
            Text(text)
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.opacity)
        }
        .foregroundStyle(ChurchTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(ChurchTheme.surfaceWarm, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: text)
    }

    @ViewBuilder private var indicator: some View {
        switch indicatorStyle {
        case .dot:
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        case .pulse:
            CalmPulseDot(color: color)
        case .progress:
            ProgressView()
                .controlSize(.mini)
                .tint(color)
                .frame(width: 10, height: 10)
        }
    }
}

private struct CalmPulseDot: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                    let duration = 1.6
                    let phase =
                        context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: duration) / duration
                    Circle()
                        .stroke(color.opacity(0.42 * (1 - phase)), lineWidth: 1)
                        .frame(width: 8, height: 8)
                        .scaleEffect(1 + (phase * 0.85))
                }
            }
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .frame(width: 12, height: 12)
    }
}
