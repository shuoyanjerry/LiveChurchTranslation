import DiagnosticsAPI
import Foundation
import PersistenceAPI

extension InterruptedSessionRecoveryCoordinator {
    func recover(
        _ candidate: TranscriptRecoveryCandidate
    ) async -> InterruptedRecoveryOutcome {
        var outcome = await repairRecording(for: candidate)
        guard outcome.issues.isEmpty else { return outcome }
        outcome.merge(await recoverTranscript(for: candidate))
        return outcome
    }

    private func repairRecording(
        for candidate: TranscriptRecoveryCandidate
    ) async -> InterruptedRecoveryOutcome {
        guard candidate.hasRecordingActivityArtifact else { return .init() }
        do {
            guard
                try await recordings.repairInterruptedRecording(
                    sessionID: candidate.sessionID
                ) != nil
            else { return .init() }
            await diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "StartupRecovery",
                    message: "已恢复一份因中断而未完成的 CAF 录音（会议标识："
                        + "\(candidate.sessionID.uuidString)）。",
                    measurements: ["recording_recovered": 1]
                )
            )
            return InterruptedRecoveryOutcome(repairedRecordingCount: 1)
        } catch {
            let issue = InterruptedSessionRecoveryIssue(
                code: .recordingRepairFailed,
                stage: .recording,
                sessionID: candidate.sessionID,
                message: "录音自动恢复失败，原始录音资料已保留，可在下次启动时重试。",
                technicalDetail: error.localizedDescription
            )
            await record(issue, severity: .error)
            return InterruptedRecoveryOutcome(issues: [issue])
        }
    }

    private func recoverTranscript(
        for candidate: TranscriptRecoveryCandidate
    ) async -> InterruptedRecoveryOutcome {
        guard candidate.requiresTranscriptRecovery else { return .init() }
        do {
            let summary = try await recovery.summary(for: candidate.sessionID)
            let result = try await transcripts.recoverInterruptedSession(
                sessionID: candidate.sessionID,
                finalization: TranscriptFinalization(
                    recovery: summary,
                    kind: .recoveredAfterInterruption
                )
            )
            return await transcriptOutcome(result, sessionID: candidate.sessionID)
        } catch {
            let issue = InterruptedSessionRecoveryIssue(
                code: .transcriptRepairFailed,
                stage: .transcript,
                sessionID: candidate.sessionID,
                message: "听抄稿自动恢复失败，原始资料未被修改，可在下次启动时重试。",
                technicalDetail: error.localizedDescription
            )
            await record(issue, severity: .error)
            return InterruptedRecoveryOutcome(issues: [issue])
        }
    }

    private func transcriptOutcome(
        _ result: InterruptedTranscriptRecoveryResult,
        sessionID: UUID
    ) async -> InterruptedRecoveryOutcome {
        switch result {
        case .recovered(let recovered):
            await diagnostics.record(
                DiagnosticEvent(
                    severity: .info,
                    component: "StartupRecovery",
                    message: "已恢复一份因中断而未完成的听抄稿清单（会议标识："
                        + "\(sessionID.uuidString)）。",
                    measurements: ["entry_count": Double(recovered.entryCount)]
                )
            )
            return InterruptedRecoveryOutcome(recoveredTranscriptCount: 1)
        case .skippedActive:
            return InterruptedRecoveryOutcome(skippedActiveCount: 1)
        case .notRequired:
            return .init()
        }
    }
}
