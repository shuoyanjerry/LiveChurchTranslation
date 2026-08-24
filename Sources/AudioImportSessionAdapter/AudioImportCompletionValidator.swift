import AudioImportAPI
import Foundation
import SessionManagementAPI

public enum AudioImportCompletionValidator {
    public static func validate(
        _ snapshot: LiveSessionSnapshot,
        savedSessionID: UUID? = nil
    ) throws {
        switch snapshot.finalizationOutcome {
        case .saved:
            if case .failed = snapshot.phase {
                throw AudioImportError.savedWithIncompleteTranscript(
                    sessionID: savedSessionID
                )
            }
            return
        case .savedWithUnresolvedUtterances, .savedWithIncompleteTranscript:
            throw AudioImportError.savedWithIncompleteTranscript(
                sessionID: savedSessionID
            )
        case .saveFailed(let message, _):
            throw AudioImportError.transcriptionFailed(message)
        case .cancelledBeforeCapture:
            throw AudioImportError.cancelled
        case .failedBeforeCapture:
            throw AudioImportError.transcriptionFailed(snapshot.statusMessage)
        case nil:
            if case .failed(let message) = snapshot.phase {
                throw AudioImportError.transcriptionFailed(message)
            }
            throw AudioImportError.transcriptionFailed("处理已结束，但没有生成结果。")
        }
    }
}
