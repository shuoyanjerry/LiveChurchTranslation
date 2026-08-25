import AudioCaptureAPI
import RemoteSharingFeatureAPI
import SessionManagementAPI
import SettingsAPI
import SwiftUI
import UIDesignSystem

extension LiveReaderHeader {
    func selectInput(_ id: AudioInputID?) {
        Task { await viewModel.selectAudioInput(id) }
    }

    var selectedInputName: String {
        guard let id = viewModel.selectedInputID else {
            return displayLanguage.interfaceText("系统默认麦克风")
        }
        return viewModel.devices.first(where: { $0.id == id })?.name
            ?? displayLanguage.interfaceText("所选麦克风")
    }

    func microphoneControlTitle(expanded: Bool) -> String {
        guard !expanded else { return selectedInputName }
        return displayLanguage.interfaceText(MicrophoneControlPresentation.settingsTitle)
    }

    var microphoneSelection: Binding<AudioInputID?> {
        Binding(
            get: { viewModel.selectedInputID },
            set: { id in selectInput(id) }
        )
    }

    var microphonePicker: some View {
        Picker(
            displayLanguage.interfaceText(MicrophoneControlPresentation.settingsTitle),
            selection: microphoneSelection
        ) {
            Text(verbatim: displayLanguage.interfaceText("系统默认麦克风"))
                .tag(Optional<AudioInputID>.none)
            ForEach(viewModel.devices) { device in
                Text(verbatim: device.name).tag(Optional(device.id))
            }
        }
        .pickerStyle(.inline)
    }

    var sharingLabel: String {
        let label =
            switch sharingState {
            case .off:
                "共享"
            case .starting:
                "正在开启"
            case .on(_, let connectionCount, _, _):
                connectionCount > 0 ? "听众 · \(connectionCount)" : "等待听众"
            case .localNetworkPermissionDenied, .failed:
                "共享未开启"
            }
        return displayLanguage.interfaceText(label)
    }

    var sharingAccessibilityValue: String {
        let value =
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
        return displayLanguage.interfaceText(value)
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
            nil
        case .on:
            ChurchTheme.live
        case .localNetworkPermissionDenied, .failed:
            ChurchTheme.danger
        }
    }

    var sharingShowsProgress: Bool {
        guard case .starting = sharingState else { return false }
        return true
    }

    var modelStatusText: String {
        let statusText: String
        if let finalizationStatusText {
            statusText = finalizationStatusText
        } else if case .idle = viewModel.snapshot.phase {
            statusText =
                switch viewModel.modelPreparationSnapshot.phase {
                case .idle, .ready: "可以开始"
                case .checking, .downloading, .loading, .retrying: "准备中"
                case .failed: "无法开始"
                }
        } else {
            statusText = LiveSessionStatusPresentation.label(for: viewModel.snapshot.phase)
        }
        return displayLanguage.interfaceText(statusText)
    }

    var statusIndicatorStyle: StatusPillIndicatorStyle {
        if case .idle = viewModel.snapshot.phase {
            return switch viewModel.modelPreparationSnapshot.phase {
            case .checking, .downloading, .loading, .retrying: .progress
            case .idle, .ready, .failed: .dot
            }
        }
        return LiveSessionStatusPresentation.indicatorStyle(for: viewModel.snapshot.phase)
    }

    var statusColor: Color {
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
        displayLanguage.interfaceText(viewModel.isRunning ? "停止" : "开始")
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
