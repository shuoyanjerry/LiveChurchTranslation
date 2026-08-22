import SwiftUI

/// Northville-inspired semantic colors for the quiet reader experience.
///
/// The palette is original to this application and does not embed church artwork.
public enum ChurchTheme {
    public static let background = Color(red: 0.961, green: 0.961, blue: 0.969)
    public static let surface = Color.white
    public static let surfaceWarm = Color(red: 0.929, green: 0.949, blue: 0.933)
    public static let stone = Color(red: 0.843, green: 0.871, blue: 0.847)
    public static let ink = Color(red: 0.118, green: 0.145, blue: 0.129)
    public static let muted = Color(red: 0.396, green: 0.439, blue: 0.416)
    public static let olive = Color(red: 0.4, green: 0.455, blue: 0.353)
    public static let gold = Color(red: 0.725, green: 0.573, blue: 0.294)
    public static let walnut = Color(red: 0.478, green: 0.376, blue: 0.282)
    public static let focus = Color(red: 0.306, green: 0.431, blue: 0.49)
    public static let live = Color(red: 0.247, green: 0.435, blue: 0.314)
    public static let warning = Color(red: 0.624, green: 0.416, blue: 0.137)
    public static let danger = Color(red: 0.722, green: 0.278, blue: 0.227)

    // Compatibility aliases keep feature code semantic while the palette evolves.
    public static let panel = surface
    public static let panelBorder = stone
    public static let primary = gold
    public static let secondaryText = muted
}
