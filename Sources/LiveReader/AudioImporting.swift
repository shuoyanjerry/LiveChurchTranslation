import Foundation
import SessionManagementAPI

public protocol AudioImporting: Sendable {
    func importAudio(from url: URL) async throws
    func cancelImport() async
}

public enum AudioImportError: LocalizedError, Sendable {
    case liveSessionRunning
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .liveSessionRunning:
            "Stop live translation before importing an audio file."
        case .transcriptionFailed(let message):
            "Audio transcription failed: \(message)"
        }
    }
}

public enum AudioImportCompletionValidator {
    public static func validate(_ snapshot: LiveSessionSnapshot) throws {
        if case .failed(let message) = snapshot.phase {
            throw AudioImportError.transcriptionFailed(message)
        }
        switch snapshot.finalizationOutcome {
        case .saved:
            return
        case .savedWithUnresolvedUtterances(let count):
            throw AudioImportError.transcriptionFailed(
                "The transcript has \(count) unfinished segment(s) saved for recovery. "
                    + "Retry the original file to create a complete transcript."
            )
        case .saveFailed(let message, _):
            throw AudioImportError.transcriptionFailed(message)
        case .cancelledBeforeCapture:
            throw AudioImportError.transcriptionFailed("Processing was cancelled before decoding.")
        case .failedBeforeCapture:
            throw AudioImportError.transcriptionFailed(snapshot.statusMessage)
        case nil:
            throw AudioImportError.transcriptionFailed("Processing ended without a result.")
        }
    }
}
