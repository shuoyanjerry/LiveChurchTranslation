import PersistenceAPI
import SwiftUI
import TranscriptAPI
import UIDesignSystem

struct SessionLibraryDetail: View {
    @ObservedObject var viewModel: SessionLibraryViewModel
    @Binding var confirmsDeletion: Bool
    let onRetranscribe: (StoredSessionSummary) -> Void
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
            detailBody(summary: summary, session: session)
        }
    }

    private func detailBody(
        summary: StoredSessionSummary,
        session: TranscriptSession
    ) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let presentation = IncompleteTranscriptPresentation(summary: summary) {
                    IncompleteTranscriptNotice(
                        presentation: presentation,
                        canRetranscribe: viewModel.recordingURL(for: summary) != nil
                            && summary.storedTranslationMode != nil,
                        isDisabled: viewModel.isImporting || viewModel.selectedSessionIsActive,
                        action: { onRetranscribe(summary) }
                    )
                    Divider().overlay(ChurchTheme.stone)
                }
                if viewModel.recordingURL(for: summary) != nil {
                    LibraryAudioPlayer(viewModel: player)
                    Divider().overlay(ChurchTheme.stone)
                }
                transcriptEntries(session)
            }
            .frame(maxWidth: 920, alignment: .leading)
            .padding(.horizontal, 42)
            .padding(.bottom, 44)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private func transcriptEntries(_ session: TranscriptSession) -> some View {
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

    private func detailHeader(_ summary: StoredSessionSummary) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                summaryTitle(summary)
                Spacer()
                detailActions
            }
            VStack(alignment: .leading, spacing: 10) {
                summaryTitle(summary)
                detailActions
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(minHeight: 76, alignment: .leading)
        .background(ChurchTheme.surface)
    }

    private func summaryTitle(_ summary: StoredSessionSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.displayTitle)
                .font(.system(size: 23, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(summary.recognitionLanguage)
                .font(.callout)
                .foregroundStyle(ChurchTheme.muted)
        }
    }

    private var detailActions: some View {
        HStack(spacing: 12) {
            Button("在访达中显示", systemImage: "folder") {
                viewModel.revealSelected()
            }
            Button("删除", systemImage: "trash", role: .destructive) {
                confirmsDeletion = true
            }
            .disabled(viewModel.selectedSessionIsActive || viewModel.isImporting)
            .help(
                viewModel.selectedSessionIsActive || viewModel.isImporting
                    ? "请先等待当前处理完成。" : "删除这场会议"
            )
        }
    }
}
