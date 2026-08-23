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
        guard let status = viewModel.snapshot.modelStatus else { return "LOCAL · ON-DEVICE" }
        switch status.state {
        case .missing: return "MODELS REQUIRED"
        case .downloading(let progress): return "DOWNLOADING \(Int(progress * 100))%"
        case .available, .loading: return "LOADING MODELS"
        case .ready: return "LOCAL · MODELS READY"
        case .failed: return "MODEL ERROR"
        }
    }

    var statusColor: Color {
        if viewModel.recordingStartedAt != nil { return ChurchTheme.danger }
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
