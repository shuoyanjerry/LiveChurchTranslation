import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct LibraryTranscriptEntry: View {
    let entry: TranscriptEntry

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            Text(TranscriptTimestamp.format(milliseconds: entry.startedMilliseconds))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ChurchTheme.muted)
                .frame(width: 68, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.targetText)
                    .font(.system(size: 22, design: .serif))
                    .lineSpacing(5)
                    .foregroundStyle(ChurchTheme.ink)
                    .textSelection(.enabled)
                Text(entry.sourceText)
                    .font(.callout)
                    .foregroundStyle(ChurchTheme.muted)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 22)
        .overlay(alignment: .bottom) {
            Divider().overlay(ChurchTheme.stone.opacity(0.7))
        }
    }
}
