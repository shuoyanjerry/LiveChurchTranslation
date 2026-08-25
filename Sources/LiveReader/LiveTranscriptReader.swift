import SettingsAPI
import SwiftUI
import UIDesignSystem

struct LiveTranscriptReader: View {
    @ObservedObject var viewModel: LiveReaderViewModel
    @State var liveFollow = LiveFollowState()
    @State private var userIsScrolling = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.interfaceDisplayLanguage) var displayLanguage

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                transcriptScrollView(proxy: proxy)
                if !liveFollow.isFollowingLive {
                    jumpToLiveButton(proxy: proxy)
                }
            }
        }
    }

    private func transcriptScrollView(proxy: ScrollViewProxy) -> some View {
        ScrollView {
            transcriptContent
        }
        .onScrollGeometryChange(for: ReaderViewport.self) { geometry in
            let distance =
                geometry.contentSize.height
                - geometry.contentOffset.y
                - geometry.containerSize.height
            return ReaderViewport(offsetY: geometry.contentOffset.y, isAtLiveEdge: distance < 96)
        } action: { oldViewport, newViewport in
            guard userIsScrolling else { return }
            guard abs(oldViewport.offsetY - newViewport.offsetY) > 0.5 else { return }
            liveFollow.userDidScroll(isAtLiveEdge: newViewport.isAtLiveEdge)
        }
        .onScrollPhaseChange { _, phase in
            userIsScrolling = phase.isUserDriven
        }
        .onChange(of: viewModel.snapshot.transcript.last?.id) {
            guard liveFollow.contentDidAppend() else { return }
            scrollToLive(proxy)
        }
        .scrollIndicators(.visible)
    }

    private var transcriptContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            readerToolbar
            if viewModel.snapshot.transcript.isEmpty {
                LiveReaderEmptyState(mode: viewModel.settings.translationMode)
            }
            ForEach(viewModel.snapshot.transcript) { entry in
                TranscriptPassage(
                    entry: entry,
                    settings: viewModel.settings,
                    isLatest: entry.id == viewModel.snapshot.transcript.last?.id
                )
                .id(entry.id)
                .padding(.top, 26)
            }
            Color.clear.frame(height: 44).id("live-edge")
        }
        .padding(.horizontal, 36)
        .padding(.top, 28)
        .frame(maxWidth: 1_180, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    private func jumpToLiveButton(proxy: ScrollViewProxy) -> some View {
        Button {
            liveFollow.jumpToLive()
            scrollToLive(proxy)
        } label: {
            Label(jumpLabel, systemImage: "arrow.down.to.line.compact")
        }
        .buttonStyle(ChurchSecondaryButtonStyle())
        .padding(28)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
        .accessibilityHint("返回最新一段翻译")
    }
}
