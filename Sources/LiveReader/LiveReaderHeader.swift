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
        ViewThatFits(in: .horizontal) {
            expandedHeader
            compactHeader
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 76)
        .background(ChurchTheme.surface)
    }

    private var expandedHeader: some View {
        HStack(spacing: 14) {
            title
            StatusPill(
                text: modelStatusText,
                color: statusColor
            )
            if viewModel.modelPreparationSnapshot.canRetry, !viewModel.isRunning {
                Button("重试", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retryModelPreparation() }
                }
                .buttonStyle(ChurchSecondaryButtonStyle())
                .help("重新准备")
            }
            if let startedAt = viewModel.recordingStartedAt {
                RecordingIndicator(startedAt: startedAt)
            }
            Spacer(minLength: 24)
            sharingButton
            optionsMenu
            inputMenu
            sessionButton
        }
    }

    private var title: some View {
        HStack(spacing: 13) {
            Image(systemName: "book.pages")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(ChurchTheme.olive)
                .frame(width: 42, height: 42)
                .background(ChurchTheme.surfaceWarm, in: Circle())
            Text("Live Church Translation")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundStyle(ChurchTheme.ink)
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
        .accessibilityLabel("听众共享")
        .accessibilityValue(sharingAccessibilityValue)
        .accessibilityHint("打开共享设置")
        .help("让听众查看实时字幕")
    }

    private var inputMenu: some View {
        Menu {
            microphonePicker
        } label: {
            InlineMenuLabel(title: selectedInputName, systemImage: "mic")
        }
        .menuIndicator(.hidden)
        .buttonStyle(ChurchSecondaryButtonStyle())
        .fixedSize(horizontal: true, vertical: false)
        .disabled(viewModel.sessionControlsLocked)
        .accessibilityLabel("音频输入")
        .accessibilityValue(selectedInputName)
    }
}
