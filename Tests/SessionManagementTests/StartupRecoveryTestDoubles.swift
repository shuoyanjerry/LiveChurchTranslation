import AudioCaptureAPI
import Foundation
import PersistenceAPI
import RecordingAPI

actor StartupRecoveryCallLog {
    private var calls: [String] = []

    func append(_ value: String) { calls.append(value) }
    func values() -> [String] { calls }
}

actor StartupTranscriptRecoveryStore: InterruptedTranscriptRecoveryStore {
    private let scan: TranscriptRecoveryScan
    private let calls: StartupRecoveryCallLog
    private let recoveryResult: InterruptedTranscriptRecoveryResult

    init(
        scan: TranscriptRecoveryScan,
        calls: StartupRecoveryCallLog,
        recoveryResult: InterruptedTranscriptRecoveryResult
    ) {
        self.scan = scan
        self.calls = calls
        self.recoveryResult = recoveryResult
    }

    func interruptedSessions(maximumCount _: Int) -> TranscriptRecoveryScan { scan }

    func recoverInterruptedSession(
        sessionID _: UUID,
        finalization _: TranscriptFinalization
    ) async -> InterruptedTranscriptRecoveryResult {
        await calls.append("transcript")
        return recoveryResult
    }
}

actor StartupRecordingRecoveryStore: SessionRecordingStore {
    private let calls: StartupRecoveryCallLog
    private let result: SessionRecordingMetadata?
    private let failure: RecordingStoreError?

    init(
        calls: StartupRecoveryCallLog,
        result: SessionRecordingMetadata? = nil,
        failure: RecordingStoreError? = nil
    ) {
        self.calls = calls
        self.result = result
        self.failure = failure
    }

    func begin(sessionID _: UUID) {}
    func append(_: AudioFrame, to _: UUID) {}
    func discard(sessionID _: UUID) {}

    func finish(sessionID: UUID) throws -> SessionRecordingMetadata {
        throw RecordingStoreError.noAudio(sessionID)
    }

    func repairInterruptedRecording(
        sessionID _: UUID
    ) async throws -> SessionRecordingMetadata? {
        await calls.append("recording")
        if let failure { throw failure }
        return result
    }
}
