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

    var sharingLabel: String {
        if case .on(_, let connectionCount, _, _) = sharingState, connectionCount > 0 {
            return "听众 · \(connectionCount)"
        }
        return "听众共享"
    }

    var modelStatusText: String {
        if viewModel.recordingStartedAt != nil { return "正在录音 · 仅本机" }
        switch viewModel.modelPreparationSnapshot.phase {
        case .idle: return "本机离线处理"
        case .checking: return "正在校验内置模型"
        case .downloading(let progress): return "正在修复模型 · \(Int(progress * 100))%"
        case .loading: return "正在载入模型"
        case .retrying(let attempt): return "正在重试 · 第 \(attempt) 次"
        case .ready: return "本机模型已就绪"
        case .failed: return "模型无法使用"
        }
    }

    var statusColor: Color {
        if viewModel.recordingStartedAt != nil { return ChurchTheme.danger }
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
        viewModel.isRunning ? "停止" : "开始翻译"
    }

    var sessionButtonIcon: String {
        viewModel.isRunning ? "stop.fill" : "mic.fill"
    }
}
