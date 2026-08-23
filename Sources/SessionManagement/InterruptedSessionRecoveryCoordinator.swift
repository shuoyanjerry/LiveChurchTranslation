import DiagnosticsAPI
import Foundation
import PersistenceAPI
import RecordingAPI
import UtteranceRecoveryAPI

public struct InterruptedSessionRecoveryCoordinator: Sendable {
    let transcripts: any InterruptedTranscriptRecoveryStore
    let recordings: any SessionRecordingStore
    let recovery: any UtteranceRecoveryStore
    let diagnostics: any DiagnosticsRecorder
    let maximumSessions: Int

    public init(
        transcripts: any InterruptedTranscriptRecoveryStore,
        recordings: any SessionRecordingStore,
        recovery: any UtteranceRecoveryStore,
        diagnostics: any DiagnosticsRecorder,
        maximumSessions: Int = 512
    ) {
        self.transcripts = transcripts
        self.recordings = recordings
        self.recovery = recovery
        self.diagnostics = diagnostics
        self.maximumSessions = max(1, maximumSessions)
    }

    @discardableResult
    public func recover() async -> InterruptedSessionRecoveryReport {
        let scan = await transcripts.interruptedSessions(maximumCount: maximumSessions)
        var outcome = await scanOutcome(scan)
        for candidate in scan.candidates {
            outcome.merge(await recover(candidate))
        }
        return outcome.report(
            candidateCount: scan.candidates.count,
            didReachLimit: scan.didReachLimit
        )
    }
}
