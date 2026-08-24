import AudioCaptureAPI
import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

extension LiveReaderHeader {
    func selectInput(_ id: AudioInputID?) {
        Task { await viewModel.selectAudioInput(id) }
    }

    var selectedInputName: String {
        guard let id = viewModel.selectedInputID else { return "系统默认麦克风" }
        return viewModel.devices.first(where: { $0.id == id })?.name ?? "所选麦克风"
    }

    var microphoneSelection: Binding<AudioInputID?> {
        Binding(
            get: { viewModel.selectedInputID },
            set: { id in selectInput(id) }
        )
    }

    var microphonePicker: some View {
        Picker("麦克风", selection: microphoneSelection) {
            Text("系统默认麦克风").tag(Optional<AudioInputID>.none)
            ForEach(viewModel.devices) { device in
                Text(device.name).tag(Optional(device.id))
            }
        }
        .pickerStyle(.inline)
    }

    var sharingLabel: String {
        switch sharingState {
        case .off:
            return "共享"
        case .starting:
            return "正在开启"
        case .on(_, let connectionCount, _, _):
            return connectionCount > 0 ? "听众 · \(connectionCount)" : "等待听众"
        case .localNetworkPermissionDenied, .failed:
            return "共享未开启"
        }
    }

    var sharingAccessibilityValue: String {
        switch sharingState {
        case .off:
            "已关闭"
        case .starting:
            "正在开启"
        case .on(_, let connectionCount, _, _):
            connectionCount > 0 ? "已开启，\(connectionCount) 位听众" : "已开启，等待听众"
        case .localNetworkPermissionDenied, .failed:
            "未开启"
        }
    }

    var compactSharingConnectionCount: Int? {
        guard case .on(_, let connectionCount, _, _) = sharingState, connectionCount > 0 else {
            return nil
        }
        return connectionCount
    }

    var compactSharingIndicatorColor: Color? {
        switch sharingState {
        case .off:
            nil
        case .starting:
            ChurchTheme.warning
        case .on:
            ChurchTheme.live
        case .localNetworkPermissionDenied, .failed:
            ChurchTheme.danger
        }
    }

    var modelStatusText: String {
        if viewModel.recordingStartedAt != nil { return "正在录音" }
        if let finalizationStatusText { return finalizationStatusText }
        if case .failed = viewModel.snapshot.phase { return "未完成" }
        switch viewModel.modelPreparationSnapshot.phase {
        case .idle, .ready: return "可以开始"
        case .checking, .downloading, .loading, .retrying: return "准备中"
        case .failed: return "无法开始"
        }
    }

    var statusColor: Color {
        if viewModel.recordingStartedAt != nil { return ChurchTheme.danger }
        if let finalizationStatusColor { return finalizationStatusColor }
        if case .failed = viewModel.snapshot.phase { return ChurchTheme.danger }
        if !viewModel.isRunning {
            return switch viewModel.modelPreparationSnapshot.phase {
            case .failed: ChurchTheme.danger
            case .checking, .downloading, .loading, .retrying: ChurchTheme.warning
            case .idle, .ready: ChurchTheme.olive
            }
        }
        return switch viewModel.snapshot.phase {
        case .failed: ChurchTheme.danger
        case .idle: ChurchTheme.olive
        case .requestingPermission, .preparingModel: ChurchTheme.warning
        default: ChurchTheme.live
        }
    }

    var sessionButtonTitle: String {
        viewModel.isRunning ? "停止" : "开始"
    }

    var sessionButtonIcon: String {
        viewModel.isRunning ? "stop.fill" : "mic.fill"
    }

    private var finalizationStatusText: String? {
        switch viewModel.snapshot.finalizationOutcome {
        case .savedWithUnresolvedUtterances:
            "部分内容待补全"
        case .savedWithIncompleteTranscript:
            "内容不完整"
        case .saveFailed:
            "未能保存"
        case .failedBeforeCapture:
            "无法开始"
        case .saved, .cancelledBeforeCapture, nil:
            nil
        }
    }

    private var finalizationStatusColor: Color? {
        switch viewModel.snapshot.finalizationOutcome {
        case .savedWithUnresolvedUtterances:
            ChurchTheme.warning
        case .savedWithIncompleteTranscript, .saveFailed, .failedBeforeCapture:
            ChurchTheme.danger
        case .saved, .cancelledBeforeCapture, nil:
            nil
        }
    }
}
