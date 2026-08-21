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
                .shadow(color: pulses ? color.opacity(0.8) : .clear, radius: 5)
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color.black.opacity(0.22), in: Capsule())
    }
}
