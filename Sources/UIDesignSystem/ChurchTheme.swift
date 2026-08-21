import SwiftUI

public enum ChurchTheme {
    public static let backgroundTop = Color(red: 0.055, green: 0.075, blue: 0.11)
    public static let backgroundBottom = Color(red: 0.025, green: 0.035, blue: 0.06)
    public static let panel = Color.white.opacity(0.075)
    public static let panelBorder = Color.white.opacity(0.12)
    public static let primary = Color(red: 0.94, green: 0.73, blue: 0.34)
    public static let live = Color(red: 0.35, green: 0.86, blue: 0.62)
    public static let warning = Color(red: 1, green: 0.62, blue: 0.32)
    public static let danger = Color(red: 1, green: 0.38, blue: 0.42)
    public static let secondaryText = Color.white.opacity(0.62)

    public static var background: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
