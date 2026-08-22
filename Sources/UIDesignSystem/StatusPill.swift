import SwiftUI

public struct StatusPill: View {
    private let text: String
    private let color: Color
    private let pulses: Bool

    public init(text: String, color: Color, pulses: Bool = false) {
        self.text = text
        self.color = color
        self.pulses = pulses
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(ChurchTheme.muted)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(ChurchTheme.surfaceWarm, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityValue(pulses ? "Active" : "Inactive")
    }
}
