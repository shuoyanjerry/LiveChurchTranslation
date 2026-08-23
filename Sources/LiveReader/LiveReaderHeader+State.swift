import AudioCaptureAPI
import RemoteSharingFeatureAPI
import SwiftUI
import UIDesignSystem

extension LiveReaderHeader {
    func selectInput(_ id: AudioInputID?) {
        Task { await viewModel.selectAudioInput(id) }
    }

    var selectedInputName: String {
        guard let id = viewModel.selectedInputID else { return "System Default" }
        return viewModel.devices.first(where: { $0.id == id })?.name ?? "Selected Input"
    }

    var sharingLabel: String {
        if case .on(_, let connectionCount, _, _) = sharingState, connectionCount > 0 {
            return "Share · \(connectionCount)"
        }
        return "Share"
    }

    var modelStatusText: String {
        if viewModel.recordingStartedAt != nil { return "RECORDING · LOCAL" }
        switch viewModel.modelPreparationSnapshot.phase {
        case .idle: return "LOCAL · ON-DEVICE"
        case .checking: return "CHECKING MODELS"
        case .downloading(let progress): return "DOWNLOADING \(Int(progress * 100))%"
        case .loading: return "LOADING MODELS"
        case .retrying(let attempt): return "RETRYING · \(attempt)"
        case .ready: return "LOCAL · MODELS READY"
        case .failed: return "MODEL ERROR"
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
        viewModel.isRunning ? "Stop" : "Start Translation"
    }

    var sessionButtonIcon: String {
        viewModel.isRunning ? "stop.fill" : "mic.fill"
    }
}
