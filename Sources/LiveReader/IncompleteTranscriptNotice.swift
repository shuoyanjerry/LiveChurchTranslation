import SettingsAPI
import SwiftUI
import UIDesignSystem

struct IncompleteTranscriptNotice: View {
    let presentation: IncompleteTranscriptPresentation
    let canRetranscribe: Bool
    let isDisabled: Bool
    let action: () -> Void
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChurchTheme.olive)
            VStack(alignment: .leading, spacing: 7) {
                Text(verbatim: displayLanguage.interfaceText(presentation.title))
                    .font(.headline)
                Text(
                    verbatim: displayLanguage.interfaceText(
                        presentation.detail(canRetranscribe: canRetranscribe)
                    )
                )
                .font(.callout)
                .foregroundStyle(ChurchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
                if canRetranscribe {
                    Button("用完整录音重新听抄", systemImage: "arrow.clockwise", action: action)
                        .buttonStyle(.borderless)
                        .disabled(isDisabled)
                }
            }
        }
        .padding(.vertical, 18)
        .accessibilityElement(children: .contain)
    }
}
