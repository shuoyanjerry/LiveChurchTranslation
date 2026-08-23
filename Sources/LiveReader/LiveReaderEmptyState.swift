import SettingsAPI
import SwiftUI
import UIDesignSystem

struct LiveReaderEmptyState: View {
    let mode: TranslationMode

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ChurchTheme.olive)
            Text(emptyTitle)
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(ChurchTheme.ink)
            Text(
                "Choose an audio input and start translation. "
                    + "The complete transcript remains available here and is saved automatically."
            )
            .font(.callout)
            .foregroundStyle(ChurchTheme.muted)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(.leading, 110)
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .leading)
    }

    private var emptyTitle: String {
        switch mode {
        case .mandarinToEnglish: "A quiet place for the English translation."
        case .englishToSimplifiedChinese: "安静、清晰地阅读中文翻译。"
        }
    }
}
