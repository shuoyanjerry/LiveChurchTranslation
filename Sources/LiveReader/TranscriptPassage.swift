import Foundation
import SettingsAPI
import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct TranscriptPassage: View {
    let entry: TranscriptEntry
    let settings: AppSettings
    let isLatest: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 26) {
            Text(TranscriptTimestamp.format(milliseconds: entry.startedMilliseconds))
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(ChurchTheme.muted.opacity(0.78))
                .frame(width: 70, alignment: .trailing)
                .accessibilityLabel("时间点")
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.targetText)
                    .font(.system(size: settings.readerFontSize, weight: .regular, design: .serif))
                    .foregroundStyle(ChurchTheme.ink)
                    .lineSpacing(7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if settings.showSourceText {
                    Text(entry.sourceText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(ChurchTheme.muted)
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .accessibilityLabel("识别原文：\(entry.sourceText)")
                }
            }
        }
        .padding(.leading, 14)
        .overlay(alignment: .leading) {
            if isLatest {
                Capsule()
                    .fill(ChurchTheme.gold)
                    .frame(width: 3)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityValue(isLatest ? "最新翻译" : "")
    }

}

enum TranscriptTimestamp {
    static func format(milliseconds: Int64) -> String {
        let totalSeconds = max(0, milliseconds / 1_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02lld:%02lld:%02lld", hours, minutes, seconds)
    }
}
