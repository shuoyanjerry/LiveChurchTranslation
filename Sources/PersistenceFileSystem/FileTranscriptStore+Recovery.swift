import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    public func interruptedSessions(maximumCount: Int) async -> TranscriptRecoveryScan {
        let requestedCount = max(0, maximumCount)
        guard requestedCount > 0 else {
            return TranscriptRecoveryScan(candidates: [], issues: [], didReachLimit: false)
        }
        guard fileManager.fileExists(atPath: root.path) else {
            return TranscriptRecoveryScan(candidates: [], issues: [], didReachLimit: false)
        }

        var issues: [TranscriptRecoveryScanIssue] = []
        do {
            let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                return scanFailure(
                    code: .unsafeRoot,
                    message: "听抄稿存储目录不安全，启动恢复已停止。"
                )
            }
        } catch {
            return scanFailure(
                code: .rootInspectionFailed,
                message: "无法检查听抄稿存储目录，启动恢复已停止。",
                technicalDetail: error.localizedDescription
            )
        }

        guard
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
                errorHandler: { url, error in
                    issues.append(
                        TranscriptRecoveryScanIssue(
                            code: .enumerationFailed,
                            sessionID: UUID(uuidString: url.lastPathComponent),
                            message: "扫描一项听抄稿资料时失败，已跳过该项。",
                            technicalDetail: error.localizedDescription
                        )
                    )
                    return true
                }
            )
        else {
            return scanFailure(
                code: .enumerationFailed,
                message: "无法扫描听抄稿存储目录，启动恢复已停止。"
            )
        }

        let candidateLimit = min(requestedCount, recoveryLimits.maximumCandidateSessions)
        var candidates: [TranscriptRecoveryCandidate] = []
        var visitedCount = 0
        var didReachLimit = requestedCount > recoveryLimits.maximumCandidateSessions

        while let item = enumerator.nextObject() as? URL {
            guard visitedCount < recoveryLimits.maximumDirectoryEntries else {
                didReachLimit = true
                break
            }
            visitedCount += 1
            guard let sessionID = UUID(uuidString: item.lastPathComponent) else { continue }
            do {
                guard try isSafeSessionDirectory(item) else {
                    issues.append(
                        TranscriptRecoveryScanIssue(
                            code: .unsafeSessionDirectory,
                            sessionID: sessionID,
                            message: "一场会议的资料目录不安全，已跳过自动恢复。"
                        )
                    )
                    continue
                }
                guard !activeSessionIDs.contains(sessionID) else { continue }
                let hasRecordingArtifact = hasRecordingActivityArtifact(sessionID: sessionID)
                let manifest = try recoveryManifest(sessionID: sessionID)
                guard manifest.id == sessionID else {
                    issues.append(
                        TranscriptRecoveryScanIssue(
                            code: .manifestIdentifierMismatch,
                            sessionID: sessionID,
                            message: "一场会议的资料标识不一致，已跳过自动恢复。"
                        )
                    )
                    continue
                }
                let requiresTranscriptRecovery = manifest.requiresInterruptionRecovery
                guard requiresTranscriptRecovery || hasRecordingArtifact else { continue }
                guard candidates.count < candidateLimit else {
                    didReachLimit = true
                    break
                }
                candidates.append(
                    TranscriptRecoveryCandidate(
                        sessionID: sessionID,
                        requiresTranscriptRecovery: requiresTranscriptRecovery,
                        hasRecordingActivityArtifact: hasRecordingArtifact
                    )
                )
            } catch {
                let hasRecordingArtifact = hasRecordingActivityArtifact(sessionID: sessionID)
                issues.append(
                    TranscriptRecoveryScanIssue(
                        code: .manifestInspectionFailed,
                        sessionID: sessionID,
                        message: "无法读取一场会议的听抄稿清单，已保留原始资料。",
                        technicalDetail: error.localizedDescription
                    )
                )
                guard candidates.count < candidateLimit else {
                    didReachLimit = true
                    break
                }
                candidates.append(
                    TranscriptRecoveryCandidate(
                        sessionID: sessionID,
                        requiresTranscriptRecovery: true,
                        hasRecordingActivityArtifact: hasRecordingArtifact
                    )
                )
            }
        }

        return TranscriptRecoveryScan(
            candidates: candidates,
            issues: issues,
            didReachLimit: didReachLimit
        )
    }

}
