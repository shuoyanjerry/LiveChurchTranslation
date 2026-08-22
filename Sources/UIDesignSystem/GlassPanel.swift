import SwiftUI

public struct GlassPanel<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(18)
            .background(ChurchTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ChurchTheme.panelBorder, lineWidth: 1)
            }
            .shadow(color: ChurchTheme.ink.opacity(0.035), radius: 12, y: 4)
    }
}
