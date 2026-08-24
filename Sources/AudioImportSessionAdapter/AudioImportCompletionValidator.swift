import AudioImportAPI
import SessionManagementAPI

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
                "听抄稿仍有 \(count) 段等待自动恢复。请重新导入原文件以生成完整听抄稿。"
            )
        case .savedWithIncompleteTranscript(let rejected, let recoverable):
            throw AudioImportError.transcriptionFailed(
                "听抄稿不完整：\(rejected) 句未生成译文，"
                    + "\(recoverable) 句等待自动恢复。完整录音已保留。"
            )
        case .saveFailed(let message, _):
            throw AudioImportError.transcriptionFailed(message)
        case .cancelledBeforeCapture:
            throw AudioImportError.cancelled
        case .failedBeforeCapture:
            throw AudioImportError.transcriptionFailed(snapshot.statusMessage)
        case nil:
            throw AudioImportError.transcriptionFailed("处理已结束，但没有生成结果。")
        }
    }
}
