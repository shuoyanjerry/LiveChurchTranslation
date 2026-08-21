import Foundation

public enum HyMT2Error: LocalizedError, Equatable, Sendable {
    case helperUnavailable(String)
    case modelUnavailable(String)
    case launchFailed(String)
    case startupTimedOut(String)
    case serverTerminated
    case modelNotLoaded
    case transportFailure(String)
    case malformedResponse
    case invalidOutput([String])

    public var errorDescription: String? {
        switch self {
        case .helperUnavailable(let path):
            "The bundled llama-server helper is unavailable at \(path)."
        case .modelUnavailable(let path):
            "The Hy-MT2 GGUF model is unavailable at \(path)."
        case .launchFailed(let message):
            "Could not launch the local translation runtime: \(message)"
        case .startupTimedOut(let message):
            "The local translation runtime did not become ready: \(message)"
        case .serverTerminated:
            "The local translation runtime stopped unexpectedly."
        case .modelNotLoaded:
            "The Hy-MT2 model has not been loaded."
        case .transportFailure(let message):
            "The local translation request failed: \(message)"
        case .malformedResponse:
            "The local translation runtime returned a malformed response."
        case .invalidOutput(let reasons):
            "The translation was rejected: \(reasons.joined(separator: "; "))."
        }
    }
}
