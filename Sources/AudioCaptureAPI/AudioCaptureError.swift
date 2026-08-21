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
            "Microphone access is not authorized."
        case .captureAlreadyRunning:
            "An audio capture stream is already running."
        case .deviceNotFound(let id):
            "The selected audio input is unavailable: \(id.rawValue)"
        case .invalidConfiguration(let message):
            "The audio capture configuration is invalid: \(message)"
        case .streamBufferOverflow:
            "Audio capture stopped because its consumer could not keep up."
        case .systemFailure(let operation, let status):
            "Core Audio failed during \(operation) (OSStatus \(status))."
        case .engineStartFailed(let message):
            "The audio engine could not start: \(message)"
        }
    }
}
