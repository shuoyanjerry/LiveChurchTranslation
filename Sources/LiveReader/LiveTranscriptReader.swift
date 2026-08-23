import SettingsAPI
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
        .accessibilityHint("返回最新一段翻译")
    }
}

extension LiveTranscriptReader {
    private var readerToolbar: some View {
        HStack(spacing: 18) {
            Text(modeCaption)
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(ChurchTheme.olive)
            Spacer()
            Picker(
                "翻译方向",
                selection: Binding(
                    get: { viewModel.settings.translationMode },
                    set: { mode in Task { await viewModel.selectTranslationMode(mode) } }
                )
            ) {
                ForEach(TranslationMode.allCases) { mode in
                    Text(mode.compactDisplayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .disabled(viewModel.sessionControlsLocked)
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
                    Text("识别原文")
                    Image(
                        systemName: viewModel.settings.showSourceText
                            ? "checkmark.circle.fill" : "circle"
                    )
                }
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ChurchTheme.olive)
            .accessibilityValue(viewModel.settings.showSourceText ? "已显示" : "已隐藏")
        }
    }

    private var modeCaption: String {
        switch viewModel.settings.translationMode {
        case .mandarinToEnglish: "普通话信息 · 英语翻译"
        case .englishToSimplifiedChinese: "英语信息 · 简体中文翻译"
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
        guard liveFollow.unseenEntryCount > 0 else { return "回到最新" }
        return "回到最新 · \(liveFollow.unseenEntryCount) 条新内容"
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
