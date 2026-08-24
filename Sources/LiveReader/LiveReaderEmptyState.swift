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
            Text("选择音频输入，然后开始翻译。")
                .font(.callout)
                .foregroundStyle(ChurchTheme.muted)
                .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(.leading, 110)
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .leading)
    }

    private var emptyTitle: String {
        switch mode {
        case .mandarinToEnglish: "英语翻译"
        case .englishToSimplifiedChinese: "简体中文翻译"
        }
    }
}
