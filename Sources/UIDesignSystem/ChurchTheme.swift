import AppKit
import SwiftUI

/// Semantic colors for the live church translation experience.
///
/// The palette is original to this application and does not embed church artwork.
public enum ChurchTheme {
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let surface = Color(nsColor: .controlBackgroundColor)
    public static let surfaceWarm = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
    public static let stone = Color(nsColor: .separatorColor)
    public static let ink = Color(nsColor: .labelColor)
    public static let muted = Color(nsColor: .secondaryLabelColor)
    public static let olive = Color(red: 0.4, green: 0.455, blue: 0.353)
    public static let gold = Color(red: 0.725, green: 0.573, blue: 0.294)
    public static let walnut = Color(red: 0.478, green: 0.376, blue: 0.282)
    public static let focus = Color(nsColor: .keyboardFocusIndicatorColor)
    public static let live = Color(nsColor: .systemGreen)
    public static let warning = Color(nsColor: .systemOrange)
    public static let danger = Color(nsColor: .systemRed)

    // Compatibility aliases keep feature code semantic while the palette evolves.
    public static let panel = surface
    public static let panelBorder = stone
    public static let primary = gold
    public static let secondaryText = muted
}
