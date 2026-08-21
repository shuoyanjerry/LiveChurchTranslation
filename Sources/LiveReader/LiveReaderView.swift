import SwiftUI
import UIDesignSystem

public struct LiveReaderView: View {
    @ObservedObject private var viewModel: LiveReaderViewModel
    @State private var showsGlossary = false
    @State private var showsSettings = false

    public init(viewModel: LiveReaderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            ChurchTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                LiveReaderHeader(
                    viewModel: viewModel,
                    showsGlossary: $showsGlossary,
                    showsSettings: $showsSettings
                )
                Divider().overlay(Color.white.opacity(0.08))
                LiveTranscriptReader(viewModel: viewModel)
            }
        }
        .frame(minWidth: 820, minHeight: 600)
        .task { await viewModel.load() }
        .sheet(isPresented: $showsGlossary) {
            GlossaryEditorView(entries: viewModel.glossaryEntries) { entries in
                Task { await viewModel.saveGlossary(entries) }
            } onRestore: {
                Task { await viewModel.restoreGlossary() }
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
}
