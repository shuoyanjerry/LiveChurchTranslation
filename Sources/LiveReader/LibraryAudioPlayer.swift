import SettingsAPI
import SwiftUI
import UIDesignSystem

struct LibraryAudioPlayer: View {
    @ObservedObject var viewModel: AudioPlayerViewModel
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("完整音频", systemImage: "waveform")
                    .font(.headline)
                Spacer()
                Text(
                    verbatim: displayLanguage.interfaceText(
                        LibraryAudioPresentation.storageLabel
                    )
                )
                .font(.caption)
                .foregroundStyle(ChurchTheme.muted)
            }
            HStack(spacing: 14) {
                Button {
                    viewModel.togglePlayback()
                } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(ChurchTheme.olive)
                .accessibilityLabel(
                    Text(
                        verbatim: displayLanguage.interfaceText(
                            viewModel.isPlaying ? "暂停" : "播放"
                        )
                    )
                )

                Text(verbatim: time(viewModel.currentTime))
                    .monospacedDigit()
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { viewModel.currentTime },
                        set: { viewModel.seek(to: $0) }
                    ),
                    in: 0...max(viewModel.duration, 0.001)
                )
                Text(verbatim: time(viewModel.duration))
                    .monospacedDigit()
                    .font(.caption)
            }
            if let error = viewModel.errorMessage {
                Text(verbatim: displayLanguage.interfaceText(error))
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.danger)
            }
        }
        .padding(.vertical, 26)
    }

    private func time(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        return String(format: "%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
    }
}

enum LibraryAudioPresentation {
    static let storageLabel = "已保存在这台 Mac 上"
}
