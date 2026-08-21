import SettingsAPI
import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct TranscriptCard: View {
    let entry: TranscriptEntry
    let settings: AppSettings

    var body: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: 16) {
                Text(String(format: "%02d", entry.sequence))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(ChurchTheme.primary)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 12) {
                    Text(entry.targetText)
                        .font(
                            .system(
                                size: settings.readerFontSize,
                                weight: .regular,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if settings.showSourceText {
                        Text(entry.sourceText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(ChurchTheme.secondaryText)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}
