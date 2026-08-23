import SwiftUI
import UIDesignSystem

struct RecordingIndicator: View {
    let startedAt: Date

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            HStack(spacing: 6) {
                Circle()
                    .fill(ChurchTheme.danger)
                    .frame(width: 7, height: 7)
                Text(elapsed(at: context.date))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ChurchTheme.muted)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("正在录音")
            .accessibilityValue(elapsed(at: context.date))
        }
    }

    private func elapsed(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(startedAt)))
        return String(format: "%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
    }
}
