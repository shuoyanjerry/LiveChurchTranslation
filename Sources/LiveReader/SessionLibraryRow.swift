import PersistenceAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

struct SessionLibraryRow: View {
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage
    let summary: StoredSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: summary.displayTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ChurchTheme.ink)
                .lineLimit(2)
            HStack(spacing: 7) {
                Image(systemName: summary.kind == .live ? "mic.fill" : "waveform")
                Text(summary.recognitionLanguage(displayLanguage: displayLanguage))
                Text("·")
                Text(displayLanguage.interfaceText("\(summary.entryCount) 段"))
            }
            .font(.caption)
            .foregroundStyle(ChurchTheme.muted)
            if summary.integrity == .active {
                Label(displayLanguage.interfaceText("处理中"), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
            } else if summary.integrity == .incomplete {
                Label(
                    displayLanguage.interfaceText("内容不完整"),
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(ChurchTheme.warning)
            } else if summary.integrity == .recoveredAfterInterruption {
                Label(displayLanguage.interfaceText("已恢复"), systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
            }
        }
        .padding(.vertical, 7)
    }
}
