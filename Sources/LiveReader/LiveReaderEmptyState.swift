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
                "选择麦克风并开始翻译。完整录音、听抄稿和翻译会自动保存在此 Mac。"
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
        case .mandarinToEnglish: "清楚呈现英语翻译。"
        case .englishToSimplifiedChinese: "清楚呈现简体中文翻译。"
        }
    }
}
