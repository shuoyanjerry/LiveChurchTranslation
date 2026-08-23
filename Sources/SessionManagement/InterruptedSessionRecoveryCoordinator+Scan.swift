import DiagnosticsAPI
import PersistenceAPI

extension InterruptedSessionRecoveryCoordinator {
    func scanOutcome(
        _ scan: TranscriptRecoveryScan
    ) async -> InterruptedRecoveryOutcome {
        var outcome = InterruptedRecoveryOutcome()
        for scanIssue in scan.issues {
            let issue = InterruptedSessionRecoveryIssue(
                code: .scanFailed,
                stage: .scan,
                sessionID: scanIssue.sessionID,
                message: scanIssue.message,
                technicalDetail: scanIssue.technicalDetail
            )
            outcome.issues.append(issue)
            await record(issue, severity: .error)
        }
        guard scan.didReachLimit else { return outcome }
        let issue = InterruptedSessionRecoveryIssue(
            code: .traversalLimitReached,
            stage: .scan,
            sessionID: nil,
            message: "启动恢复已达到安全扫描上限，其余会议资料将在下次启动时继续处理。"
        )
        outcome.issues.append(issue)
        await record(issue, severity: .warning)
        return outcome
    }
}
