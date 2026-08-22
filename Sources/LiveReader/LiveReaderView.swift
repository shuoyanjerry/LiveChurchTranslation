import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

public struct LiveReaderView: View {
    @ObservedObject private var viewModel: LiveReaderViewModel
    @State private var showsGlossary = false
    @State private var showsSettings = false
    @State private var showsSharing = false
    @State private var sharingState = LocalSharingViewState.off
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
        .preferredColorScheme(.light)
        .frame(minWidth: 1_080, minHeight: 640)
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
            "Live Translation",
            isPresented: Binding(
                get: { viewModel.presentedError != nil },
                set: { if !$0 { viewModel.presentedError = nil } }
            )
        ) {
            Button("OK") { viewModel.presentedError = nil }
        } message: {
            Text(viewModel.presentedError ?? "Unknown error")
        }
    }

    private func sendSharingIntent(_ intent: LocalSharingIntent) {
        Task { await sharingFeature.send(intent) }
    }
}
