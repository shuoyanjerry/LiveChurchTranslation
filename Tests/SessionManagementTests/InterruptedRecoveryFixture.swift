import Foundation
import PersistenceAPI
import RecordingAPI

struct InterruptedRecoveryFixture {
    let calls: StartupRecoveryCallLog
    let transcripts: StartupTranscriptRecoveryStore
    let recordings: StartupRecordingRecoveryStore

    static func successful() -> Self {
        let sessionID = UUID()
        let calls = StartupRecoveryCallLog()
        return Self(
            calls: calls,
            transcripts: transcriptStore(
                sessionID: sessionID,
                calls: calls,
                result: .recovered(
                    RecoveredTranscriptSession(
                        sessionID: sessionID,
                        endedAt: Date(timeIntervalSince1970: 100),
                        entryCount: 4
                    )
                )
            ),
            recordings: StartupRecordingRecoveryStore(
                calls: calls,
                result: SessionRecordingMetadata(
                    sessionID: sessionID,
                    fileURL: FileManager.default.temporaryDirectory.appending(path: "recording.caf"),
                    format: RecordingFormat(sampleRate: 16_000, channelCount: 1),
                    frameCount: 16_000,
                    audioDataByteCount: 32_000,
                    recoveredFromInterruption: true
                )
            )
        )
    }

    static func recordingFailure() -> Self {
        let sessionID = UUID()
        let calls = StartupRecoveryCallLog()
        return Self(
            calls: calls,
            transcripts: transcriptStore(sessionID: sessionID, calls: calls, result: .notRequired),
            recordings: StartupRecordingRecoveryStore(
                calls: calls,
                failure: RecordingStoreError.fileSystem(
                    operation: "repair",
                    reason: "Injected CAF failure"
                )
            )
        )
    }

    private static func transcriptStore(
        sessionID: UUID,
        calls: StartupRecoveryCallLog,
        result: InterruptedTranscriptRecoveryResult
    ) -> StartupTranscriptRecoveryStore {
        StartupTranscriptRecoveryStore(
            scan: TranscriptRecoveryScan(
                candidates: [
                    TranscriptRecoveryCandidate(
                        sessionID: sessionID,
                        requiresTranscriptRecovery: true,
                        hasRecordingActivityArtifact: true
                    )
                ],
                issues: [],
                didReachLimit: false
            ),
            calls: calls,
            recoveryResult: result
        )
    }
}
