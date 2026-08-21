import SwiftUI
import UIDesignSystem

struct LiveTranscriptReader: View {
    @ObservedObject var viewModel: LiveReaderViewModel
    @State private var liveFollow = LiveFollowState()

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
            LazyVStack(spacing: 14) {
                if viewModel.snapshot.transcript.isEmpty { LiveReaderEmptyState() }
                ForEach(viewModel.snapshot.transcript) { entry in
                    TranscriptCard(entry: entry, settings: viewModel.settings)
                        .id(entry.id)
                }
                Color.clear.frame(height: 20).id("live-edge")
            }
            .padding(24)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            let distance =
                geometry.contentSize.height
                - geometry.contentOffset.y
                - geometry.containerSize.height
            return distance < 90
        } action: { _, atBottom in
            liveFollow.userDidScroll(isAtLiveEdge: atBottom)
        }
        .onChange(of: viewModel.snapshot.transcript.last?.id) {
            guard liveFollow.shouldRevealNewTranscript() else { return }
            withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("live-edge") }
        }
    }

    private func jumpToLiveButton(proxy: ScrollViewProxy) -> some View {
        Button {
            liveFollow.jumpToLive()
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("live-edge") }
        } label: {
            Label("Jump to Live", systemImage: "arrow.down.to.line.compact")
        }
        .buttonStyle(ChurchPrimaryButtonStyle())
        .padding(24)
    }
}

private struct LiveReaderEmptyState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.quote")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(ChurchTheme.primary.opacity(0.8))
            Text("The complete English transcript will appear here.")
                .font(.system(size: 20, weight: .medium, design: .rounded))
            Text("Choose an input, then press Start. Every session is saved automatically.")
                .foregroundStyle(ChurchTheme.secondaryText)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 360)
    }
}
