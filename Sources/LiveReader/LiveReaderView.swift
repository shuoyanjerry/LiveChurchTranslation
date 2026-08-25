import RemoteSharingFeatureAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

public struct LiveReaderView: View {
    @ObservedObject private var viewModel: LiveReaderViewModel
    @State private var showsGlossary = false
    @State private var showsSettings = false
    @State private var showsSharing = false
    @State private var sharingState = LocalSharingViewState.off
    @Environment(\.interfaceDisplayLanguage) private var displayLanguage
    private let sharingFeature: any LocalSharingFeature

    public init(
        viewModel: LiveReaderViewModel,
        sharingFeature: any LocalSharingFeature
    ) {
        self.viewModel = viewModel
        self.sharingFeature = sharingFeature
    }

    public var body: some View {
        ZStack {
            ChurchTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                LiveReaderHeader(
                    viewModel: viewModel,
                    showsGlossary: $showsGlossary,
                    showsSettings: $showsSettings,
                    showsSharing: $showsSharing,
                    sharingState: sharingState,
                    onSharingIntent: sendSharingIntent
                )
                Divider().overlay(ChurchTheme.stone)
                LiveTranscriptReader(viewModel: viewModel)
            }
        }
        .frame(minWidth: 680, minHeight: 560)
        .task { await viewModel.load() }
        .task {
            sharingState = await sharingFeature.state()
            for await state in await sharingFeature.events() {
                sharingState = state
            }
        }
        .sheet(isPresented: $showsGlossary) {
            GlossaryEditorView(entries: viewModel.glossaryEntries) { entries in
                await viewModel.saveGlossary(entries)
            } onRestore: {
                await viewModel.restoreGlossary()
            }
        }
        .sheet(isPresented: $showsSettings) {
            SettingsView(viewModel: viewModel)
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            )
        ) {
            Button("好") { viewModel.presentedError = nil }
        } message: {
            Text(
                verbatim: displayLanguage.interfaceText(
                    viewModel.presentedError ?? "请重试。"
                )
            )
        }
        .alert("开始翻译并录音？", isPresented: $viewModel.presentsRecordingNotice) {
            Button("取消", role: .cancel) {}
            Button("开始") {
                Task { await viewModel.startRecordingAndTranslation() }
            }
        } message: {
            Text("录音与字幕会保存在这台 Mac。请确认现场人员已知情。")
        }
    }

    private func sendSharingIntent(_ intent: LocalSharingIntent) {
        Task { await sharingFeature.send(intent) }
    }
}
