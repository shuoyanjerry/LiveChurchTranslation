import Foundation
import ModelRuntimeAPI

enum ModelStatusMessage {
    static func text(for status: ModelRuntimeStatus) -> String? {
        switch status.state {
        case .missing:
            return "正在等待 \(status.descriptor.displayName)…"
        case .downloading(let progress):
            return "正在修复 \(status.descriptor.displayName) · \(Int(progress * 100))%"
        case .available:
            return "正在校验 \(status.descriptor.displayName)…"
        case .loading:
            return "正在载入 \(status.descriptor.displayName)…"
        case .ready:
            return "\(status.descriptor.displayName) 已就绪"
        case .failed(let message):
            return message
        }
    }
}
