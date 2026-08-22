import SwiftUI

public struct ChurchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(ChurchTheme.ink)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(
                ChurchTheme.primary.opacity(configuration.isPressed ? 0.72 : 1),
                in: Capsule()
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

public struct ChurchSecondaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(ChurchTheme.ink)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(
                configuration.isPressed ? ChurchTheme.surfaceWarm : ChurchTheme.surface,
                in: Capsule()
            )
            .overlay { Capsule().stroke(ChurchTheme.stone, lineWidth: 1) }
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
