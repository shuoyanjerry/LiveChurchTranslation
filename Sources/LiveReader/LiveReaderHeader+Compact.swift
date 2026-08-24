import SwiftUI
import UIDesignSystem

extension LiveReaderHeader {
    var compactHeader: some View {
        HStack(spacing: 10) {
            compactTitle
            if viewModel.modelPreparationSnapshot.canRetry, !viewModel.isRunning {
                compactRetryButton
            } else {
                StatusPill(
                    text: modelStatusText,
                    color: statusColor,
                    indicatorStyle: statusIndicatorStyle
                )
            }
            if let startedAt = viewModel.recordingStartedAt {
                RecordingIndicator(startedAt: startedAt)
            }
            Spacer(minLength: 8)
            compactSharingButton
            optionsMenu
            compactInputMenu
            sessionButton
        }
    }

    private var compactTitle: some View {
        Text("Live Church Translation")
            .font(.system(size: 16, weight: .semibold, design: .serif))
            .foregroundStyle(ChurchTheme.ink)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(2)
    }

    private var compactRetryButton: some View {
        Button {
            Task { await viewModel.retryModelPreparation() }
        } label: {
            Label("重试", systemImage: "arrow.clockwise")
                .font(.callout.weight(.medium))
                .foregroundStyle(ChurchTheme.danger)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(ChurchTheme.danger.opacity(0.1), in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("无法开始，重试")
        .help("重新准备")
    }

    private var compactSharingButton: some View {
        Button {
            showsSharing.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                Text("共享")
                    .lineLimit(1)
                if let connectionCount = compactSharingConnectionCount {
                    Text("\(connectionCount)")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                        .padding(.horizontal, 5)
                        .frame(minHeight: 18)
                        .background(ChurchTheme.live.opacity(0.14), in: Capsule())
                } else if sharingShowsProgress {
                    ProgressView()
                        .controlSize(.mini)
                        .accessibilityHidden(true)
                } else if let indicatorColor = compactSharingIndicatorColor {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6, weight: .semibold))
                        .foregroundStyle(indicatorColor)
                        .accessibilityHidden(true)
                }
            }
            .font(.callout.weight(.medium))
            .fixedSize(horizontal: true, vertical: false)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsSharing, arrowEdge: .bottom) {
            LocalSharingPopover(state: sharingState, onIntent: onSharingIntent)
        }
        .accessibilityLabel("听众共享")
        .accessibilityValue(sharingAccessibilityValue)
        .accessibilityHint("打开共享设置")
        .help("让听众查看实时字幕")
    }

    private var compactInputMenu: some View {
        Menu {
            microphonePicker
        } label: {
            InlineMenuLabel(
                title: MicrophoneControlPresentation.title(
                    selectedInputName: selectedInputName,
                    expanded: false
                ),
                systemImage: "mic"
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .foregroundStyle(ChurchTheme.ink)
        .disabled(viewModel.sessionControlsLocked)
        .accessibilityLabel(MicrophoneControlPresentation.settingsTitle)
        .accessibilityValue(selectedInputName)
        .help(selectedInputName)
    }
}
