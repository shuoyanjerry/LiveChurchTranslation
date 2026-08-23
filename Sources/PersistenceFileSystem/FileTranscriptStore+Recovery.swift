import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    public func interruptedSessions(maximumCount: Int) async -> TranscriptRecoveryScan {
        let requestedCount = max(0, maximumCount)
        guard requestedCount > 0, fileManager.fileExists(atPath: root.path) else {
            return TranscriptRecoveryScan(candidates: [], issues: [], didReachLimit: false)
        }
        if let failure = recoveryRootFailure() { return failure }

        let issueCollector = TranscriptRecoveryIssueCollector()
        guard let enumerator = recoveryEnumerator(issueCollector: issueCollector) else {
            return scanFailure(
                code: .enumerationFailed,
                message: "无法扫描听抄稿存储目录，启动恢复已停止。"
            )
        }
        return scanRecoveryItems(
            enumerator,
            requestedCount: requestedCount,
            issueCollector: issueCollector
        )
    }
}
