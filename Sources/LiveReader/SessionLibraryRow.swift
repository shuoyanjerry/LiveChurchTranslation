import PersistenceAPI
import SwiftUI
import UIDesignSystem

struct SessionLibraryRow: View {
    let summary: StoredSessionSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(summary.displayTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ChurchTheme.ink)
                .lineLimit(2)
            HStack(spacing: 7) {
                Image(systemName: summary.kind == .live ? "mic.fill" : "waveform")
                Text(summary.languagePair)
                Text("·")
                Text("\(summary.entryCount) 段")
            }
            .font(.caption)
            .foregroundStyle(ChurchTheme.muted)
        }
        .padding(.vertical, 7)
    }
}
