import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct LibraryTranscriptEntry: View {
    let entry: TranscriptEntry

    var displayText: String { entry.sourceText }

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Text(verbatim: TranscriptTimestamp.format(milliseconds: entry.startedMilliseconds))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ChurchTheme.muted)
                .frame(width: 68, alignment: .trailing)
            Text(verbatim: displayText)
                .font(.system(size: 22, design: .serif))
                .lineSpacing(5)
                .foregroundStyle(ChurchTheme.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 22)
        .overlay(alignment: .bottom) {
            Divider().overlay(ChurchTheme.stone.opacity(0.7))
        }
    }
}
