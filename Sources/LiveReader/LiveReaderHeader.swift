import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

struct LiveReaderHeader: View {
    @ObservedObject var viewModel: LiveReaderViewModel
    @Binding var showsGlossary: Bool
    @Binding var showsSettings: Bool
    @Binding var showsSharing: Bool
    let sharingState: LocalSharingViewState
    let onSharingIntent: LocalSharingIntentHandler

    var body: some View {
        HStack(spacing: 14) {
            title
            StatusPill(text: modelStatusText, color: statusColor, pulses: viewModel.isRunning)
            Spacer(minLength: 24)
            sharingButton
            optionsMenu
            inputMenu
            sessionButton
        }
        .padding(.horizontal, 28)
        .frame(minHeight: 76)
        .background(ChurchTheme.surface)
    }

    private var title: some View {
        HStack(spacing: 13) {
            Image(systemName: "book.pages")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChurchTheme.olive)
                .frame(width: 42, height: 42)
                .background(ChurchTheme.surfaceWarm, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Quiet Liturgy Reader")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(ChurchTheme.ink)
                Text(viewModel.snapshot.statusMessage)
                    .font(.caption)
                    .foregroundStyle(ChurchTheme.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
    }

    private var sharingButton: some View {
        Button {
            showsSharing.toggle()
        } label: {
            Label(sharingLabel, systemImage: "antenna.radiowaves.left.and.right")
        }
        .buttonStyle(ChurchSecondaryButtonStyle())
        .popover(isPresented: $showsSharing, arrowEdge: .bottom) {
            LocalSharingPopover(state: sharingState, onIntent: onSharingIntent)
        }
        .help("Share the live transcript on the local network")
    }

    private var optionsMenu: some View {
        Menu {
            Button("Theological Glossary", systemImage: "character.book.closed") {
                showsGlossary = true
            }
            Button("Reader Settings", systemImage: "slider.horizontal.3") {
                showsSettings = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .foregroundStyle(ChurchTheme.ink)
        .accessibilityLabel("Reader options")
    }

    private var inputMenu: some View {
        Menu {
            Button("System Default") { selectInput(nil) }
            if !viewModel.devices.isEmpty { Divider() }
            ForEach(viewModel.devices) { device in
                Button(device.name) { selectInput(device.id) }
            }
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "mic")
                Text(selectedInputName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 150)
                Image(systemName: "chevron.down").font(.caption2)
            }
        }
        .buttonStyle(ChurchSecondaryButtonStyle())
        .accessibilityLabel("Audio input")
        .accessibilityValue(selectedInputName)
    }

    private var sessionButton: some View {
        Button {
            Task { await viewModel.toggleSession() }
        } label: {
            Label(sessionButtonTitle, systemImage: sessionButtonIcon)
        }
        .buttonStyle(ChurchPrimaryButtonStyle())
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityHint("Starts or stops Chinese recognition and English translation")
    }
}
