import Foundation
import PersistenceAPI

extension FileTranscriptStore {
    func recoveryRootFailure() -> TranscriptRecoveryScan? {
        do {
            let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                return scanFailure(
                    code: .unsafeRoot,
                    message: "听抄稿存储目录不安全，启动恢复已停止。"
                )
            }
            return nil
        } catch {
            return scanFailure(
                code: .rootInspectionFailed,
                message: "无法检查听抄稿存储目录，启动恢复已停止。",
                technicalDetail: error.localizedDescription
            )
        }
    }

    func recoveryEnumerator(
        issueCollector: TranscriptRecoveryIssueCollector
    ) -> FileManager.DirectoryEnumerator? {
        fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { url, error in
                issueCollector.appendEnumerationFailure(url: url, error: error)
                return true
            }
        )
    }

    func scanRecoveryItems(
        _ enumerator: FileManager.DirectoryEnumerator,
        requestedCount: Int,
        issueCollector: TranscriptRecoveryIssueCollector
    ) -> TranscriptRecoveryScan {
        var state = TranscriptRecoveryScanState(
            requestedCount: requestedCount,
            limits: recoveryLimits
        )
        while let item = enumerator.nextObject() as? URL {
            guard state.beginVisit() else { break }
            guard let sessionID = UUID(uuidString: item.lastPathComponent) else { continue }
            let inspection = inspectRecoveryItem(item, sessionID: sessionID)
            issueCollector.append(inspection.issue)
            guard state.append(inspection.candidate) else { break }
        }
        return state.result(issues: issueCollector.issues)
    }

    func inspectRecoveryItem(
        _ item: URL,
        sessionID: UUID
    ) -> TranscriptRecoveryItemInspection {
        do {
            return try inspectReadableRecoveryItem(item, sessionID: sessionID)
        } catch {
            let candidate = recoveryCandidate(
                sessionID: sessionID,
                requiresTranscriptRecovery: true
            )
            return TranscriptRecoveryItemInspection(
                candidate: candidate,
                issue: TranscriptRecoveryScanIssue(
                    code: .manifestInspectionFailed,
                    sessionID: sessionID,
                    message: "无法读取一场会议的听抄稿清单，已保留原始资料。",
                    technicalDetail: error.localizedDescription
                )
            )
        }
    }

    private func inspectReadableRecoveryItem(
        _ item: URL,
        sessionID: UUID
    ) throws -> TranscriptRecoveryItemInspection {
        guard try isSafeSessionDirectory(item) else {
            return TranscriptRecoveryItemInspection(
                issue: TranscriptRecoveryScanIssue(
                    code: .unsafeSessionDirectory,
                    sessionID: sessionID,
                    message: "一场会议的资料目录不安全，已跳过自动恢复。"
                )
            )
        }
        guard !activeSessionIDs.contains(sessionID) else { return .skipped }
        let manifest = try recoveryManifest(sessionID: sessionID)
        guard manifest.id == sessionID else {
            return TranscriptRecoveryItemInspection(
                issue: TranscriptRecoveryScanIssue(
                    code: .manifestIdentifierMismatch,
                    sessionID: sessionID,
                    message: "一场会议的资料标识不一致，已跳过自动恢复。"
                )
            )
        }
        let hasRecordingArtifact = hasRecordingActivityArtifact(sessionID: sessionID)
        guard manifest.requiresInterruptionRecovery || hasRecordingArtifact else {
            return .skipped
        }
        return TranscriptRecoveryItemInspection(
            candidate: TranscriptRecoveryCandidate(
                sessionID: sessionID,
                requiresTranscriptRecovery: manifest.requiresInterruptionRecovery,
                hasRecordingActivityArtifact: hasRecordingArtifact
            )
        )
    }

    private func recoveryCandidate(
        sessionID: UUID,
        requiresTranscriptRecovery: Bool
    ) -> TranscriptRecoveryCandidate {
        TranscriptRecoveryCandidate(
            sessionID: sessionID,
            requiresTranscriptRecovery: requiresTranscriptRecovery,
            hasRecordingActivityArtifact: hasRecordingActivityArtifact(sessionID: sessionID)
        )
    }
}
