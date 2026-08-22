import SwiftUI
import UIDesignSystem

struct LiveTranscriptReader: View {
    @ObservedObject var viewModel: LiveReaderViewModel
    @State private var liveFollow = LiveFollowState()
    @State private var userIsScrolling = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            userIsScrolling = isUserDriven(phase)
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
            if viewModel.snapshot.transcript.isEmpty { LiveReaderEmptyState() }
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
        .frame(maxWidth: 1_180, alignment: .leading)
        .padding(.horizontal, 36)
        .padding(.top, 28)
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
        .accessibilityHint("Returns to the newest translated passage")
    }

    private var readerToolbar: some View {
        HStack {
            Text("CHINESE SERMON · ENGLISH TRANSLATION")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(ChurchTheme.olive)
            Spacer()
            Button {
                let previousSettings = viewModel.settings
                viewModel.settings.showSourceText.toggle()
                Task {
                    if !(await viewModel.saveSettings()) {
                        viewModel.settings = previousSettings
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text("Chinese source")
                    Image(
                        systemName: viewModel.settings.showSourceText
                            ? "checkmark.circle.fill" : "circle"
                    )
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ChurchTheme.olive)
            .accessibilityValue(viewModel.settings.showSourceText ? "Shown" : "Hidden")
        }
    }

    private func scrollToLive(_ proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo("live-edge", anchor: .bottom)
        } else {
            withAnimation(.easeOut(duration: 0.22)) {
                proxy.scrollTo("live-edge", anchor: .bottom)
            }
        }
    }

    private var jumpLabel: String {
        guard liveFollow.unseenEntryCount > 0 else { return "Jump to Live" }
        return "Jump to Live · \(liveFollow.unseenEntryCount) new"
    }

    private func isUserDriven(_ phase: ScrollPhase) -> Bool {
        switch phase {
        case .tracking, .interacting, .decelerating: true
        case .idle, .animating: false
        }
    }
}

private struct ReaderViewport: Equatable {
    let offsetY: CGFloat
    let isAtLiveEdge: Bool
}

private struct LiveReaderEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ChurchTheme.olive)
            Text("A quiet place for the English transcript.")
                .font(.system(size: 28, weight: .regular, design: .serif))
                .foregroundStyle(ChurchTheme.ink)
            Text(
                "Choose an audio input and start translation. "
                    + "The complete transcript remains available here and is saved automatically."
            )
            .font(.callout)
            .foregroundStyle(ChurchTheme.muted)
            .frame(maxWidth: 560, alignment: .leading)
        }
        .padding(.leading, 110)
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .leading)
    }
}
