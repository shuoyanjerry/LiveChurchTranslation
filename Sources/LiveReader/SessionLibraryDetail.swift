import PersistenceAPI
import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct SessionLibraryDetail: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    @Binding var confirmsDeletion: Bool
    @StateObject private var player = AudioPlayerViewModel()

    var body: some View {
        Group {
            if let summary = viewModel.selectedSummary, let session = viewModel.selectedSession {
                detail(summary: summary, session: session)
                    .onAppear { player.load(viewModel.recordingURL(for: summary)) }
                    .onChange(of: summary.id) {
                        player.load(viewModel.recordingURL(for: summary))
                    }
            } else {
                ContentUnavailableView(
                    "选择一个项目",
                    systemImage: "text.alignleft",
                    description: Text("在左侧选择录音或听抄稿。")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detail(
        summary: StoredSessionSummary,
        session: TranscriptSession
    ) -> some View {
        VStack(spacing: 0) {
            detailHeader(summary)
            Divider().overlay(ChurchTheme.stone)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if let audioURL = viewModel.recordingURL(for: summary) {
                        LibraryAudioPlayer(viewModel: player, url: audioURL)
                        Divider().overlay(ChurchTheme.stone)
                    }
                    if session.entries.isEmpty {
                        ContentUnavailableView(
                            "尚无听抄内容",
                            systemImage: "quote.bubble",
                            description: Text("处理完成的文字会显示在这里。")
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                        ForEach(session.entries) { entry in
                            LibraryTranscriptEntry(entry: entry)
                        }
                    }
                }
                .frame(maxWidth: 920, alignment: .leading)
                .padding(.horizontal, 42)
                .padding(.bottom, 44)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func detailHeader(_ summary: StoredSessionSummary) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.displayTitle)
                    .font(.system(size: 23, weight: .semibold))
                    .lineLimit(1)
                Text(summary.languagePair)
                    .font(.callout)
                    .foregroundStyle(ChurchTheme.muted)
            }
            Spacer()
            Button("在 Finder 中显示", systemImage: "folder") {
                viewModel.revealSelected()
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                confirmsDeletion = true
            }
            .disabled(viewModel.selectedSessionIsActive)
            .help(
                viewModel.selectedSessionIsActive
                    ? "Stop the active meeting before deleting it."
                    : "Delete this meeting"
            )
        }
        .padding(.horizontal, 28)
        .frame(minHeight: 76)
        .background(ChurchTheme.surface)
    }
}
