import SessionManagementAPI
import SwiftUI
import UIDesignSystem

struct LiveReaderHeader: View {
    @ObservedObject var viewModel: LiveReaderViewModel
    @Binding var showsGlossary: Bool
    @Binding var showsSettings: Bool

    var body: some View {
        HStack(spacing: 16) {
            title
            Spacer()
            StatusPill(
                text: viewModel.snapshot.statusMessage,
                color: statusColor,
                pulses: viewModel.isRunning
            )
            actionButton("Glossary", icon: "character.book.closed") {
                showsGlossary = true
            }
            actionButton("Settings", icon: "slider.horizontal.3") {
                showsSettings = true
            }
            Button {
                Task { await viewModel.toggleSession() }
            } label: {
                Label(viewModel.isRunning ? "Stop" : "Start", systemImage: sessionButtonIcon)
            }
            .buttonStyle(ChurchPrimaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var title: some View {
        HStack(spacing: 16) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(ChurchTheme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE CHURCH TRANSLATION")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(ChurchTheme.secondaryText)
                Text("Sermon Reader")
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }

    private func actionButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .buttonStyle(ChurchSecondaryButtonStyle())
    }

    private var statusColor: Color {
        switch viewModel.snapshot.phase {
        case .failed: ChurchTheme.danger
        case .idle: ChurchTheme.secondaryText
        case .preparingModel: ChurchTheme.warning
        default: ChurchTheme.live
        }
    }

    private var sessionButtonIcon: String {
        viewModel.isRunning ? "stop.fill" : "play.fill"
    }
}
