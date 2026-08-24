import Foundation

/// Failures exposed by an `AudioCaptureProvider` implementation.
public enum AudioCaptureError: Error, Equatable, LocalizedError, Sendable {
    case permissionDenied
    case captureAlreadyRunning
    case deviceNotFound(AudioInputID)
    case invalidConfiguration(String)
    case streamBufferOverflow
    case systemFailure(operation: String, status: Int32)
    case engineStartFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "尚未允许麦克风访问。"
        case .captureAlreadyRunning:
            "音频采集已经在运行。"
        case .deviceNotFound(let id):
            "所选音频输入当前不可用：\(id.rawValue)"
        case .invalidConfiguration(let message):
            "音频采集配置无效：\(message)"
        case .streamBufferOverflow:
            "处理速度未能跟上，录音已停止并保留已录内容。"
        case .systemFailure(let operation, let status):
            "Core Audio 在执行 \(operation) 时失败（OSStatus \(status)）。"
        case .engineStartFailed(let message):
            "音频引擎无法启动：\(message)"
        }
    }
}
