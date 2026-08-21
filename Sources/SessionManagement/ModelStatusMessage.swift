import Foundation
import ModelRuntimeAPI

enum ModelStatusMessage {
    static func text(for status: ModelRuntimeStatus) -> String? {
        switch status.state {
        case .missing:
            return "Waiting for \(status.descriptor.displayName)…"
        case .downloading(let progress):
            return "Downloading \(status.descriptor.displayName) · \(Int(progress * 100))%"
        case .available:
            return "Verifying \(status.descriptor.displayName)…"
        case .loading:
            return "Loading \(status.descriptor.displayName)…"
        case .ready:
            return "\(status.descriptor.displayName) ready"
        case .failed(let message):
            return message
        }
    }
}
