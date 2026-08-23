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
            StatusPill(
                text: modelStatusText,
                color: statusColor,
                pulses: viewModel.isRunning || viewModel.modelPreparationIsActive
            )
            if viewModel.modelPreparationSnapshot.canRetry, !viewModel.isRunning {
                Button("重试模型", systemImage: "arrow.clockwise") {
                    Task { await viewModel.retryModelPreparation() }
                }
                .buttonStyle(ChurchSecondaryButtonStyle())
                .help("重新校验并载入应用内置模型")
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
                Text("教会实时翻译")
                    .font(.system(size: 21, weight: .semibold, design: .serif))
                    .foregroundStyle(ChurchTheme.ink)
                Text(viewModel.displayedStatusMessage)
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
        .help("让同一局域网内的听众查看实时听抄与翻译")
    }

    private var optionsMenu: some View {
        Menu {
            Button("属灵术语表", systemImage: "character.book.closed") {
                showsGlossary = true
            }
            Button("阅读与翻译设置", systemImage: "slider.horizontal.3") {
                showsSettings = true
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .foregroundStyle(ChurchTheme.ink)
        .accessibilityLabel("更多选项")
    }

    private var inputMenu: some View {
        Menu {
            Button("系统默认麦克风") { selectInput(nil) }
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
        .disabled(viewModel.sessionControlsLocked)
        .accessibilityLabel("音频输入")
        .accessibilityValue(selectedInputName)
    }

    private var sessionButton: some View {
        Button {
            Task { await viewModel.toggleSession() }
        } label: {
            Label(sessionButtonTitle, systemImage: sessionButtonIcon)
        }
        .buttonStyle(ChurchPrimaryButtonStyle())
        .disabled(viewModel.externalSessionControlLock && !viewModel.isRunning)
        .keyboardShortcut(.return, modifiers: [.command])
        .accessibilityHint("开始或停止实时语音识别、翻译和录音")
    }
}
