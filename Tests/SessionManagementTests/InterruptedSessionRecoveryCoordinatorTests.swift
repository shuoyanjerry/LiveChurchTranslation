import AudioCaptureAPI
import DiagnosticsAPI
import Foundation
import PersistenceAPI
import RecordingAPI
import SessionManagement
import Testing
import UtteranceRecoveryAPI

@Suite struct InterruptedSessionRecoveryCoordinatorTests {
    @Test func repairsCAFBeforeCommittingTheTranscriptRecovery() async {
        let sessionID = UUID()
        let calls = StartupRecoveryCallLog()
        let transcripts = StartupTranscriptRecoveryStore(
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
            recoveryResult: .recovered(
                RecoveredTranscriptSession(
                    sessionID: sessionID,
                    endedAt: Date(timeIntervalSince1970: 100),
                    entryCount: 4
                )
            )
        )
        let recordings = StartupRecordingRecoveryStore(
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
        let diagnostics = FakeDiagnosticsRecorder()

        let report = await InterruptedSessionRecoveryCoordinator(
            transcripts: transcripts,
            recordings: recordings,
            recovery: FakeUtteranceRecoveryStore(),
            diagnostics: diagnostics
        ).recover()

        #expect(await calls.values() == ["recording", "transcript"])
        #expect(report.repairedRecordingCount == 1)
        #expect(report.recoveredTranscriptCount == 1)
        #expect(report.issues.isEmpty)
        #expect(await diagnostics.recordedEvents().count == 2)
    }

    @Test func recordingFailureLeavesTranscriptUncommittedAndEntersDiagnostics() async {
        let sessionID = UUID()
        let calls = StartupRecoveryCallLog()
        let transcripts = StartupTranscriptRecoveryStore(
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
            recoveryResult: .notRequired
        )
        let recordings = StartupRecordingRecoveryStore(
            calls: calls,
            failure: RecordingStoreError.fileSystem(
                operation: "repair",
                reason: "Injected CAF failure"
            )
        )
        let diagnostics = FakeDiagnosticsRecorder()

        let report = await InterruptedSessionRecoveryCoordinator(
            transcripts: transcripts,
            recordings: recordings,
            recovery: FakeUtteranceRecoveryStore(),
            diagnostics: diagnostics
        ).recover()

        #expect(await calls.values() == ["recording"])
        #expect(report.recoveredTranscriptCount == 0)
        #expect(report.issues.map(\.stage) == [.recording])
        let events = await diagnostics.recordedEvents()
        #expect(events.count == 1)
        #expect(events.first?.component == "StartupRecovery")
        #expect(events.first?.severity == .error)
    }

    @Test func scanErrorsAndTraversalLimitBecomeStartupDiagnostics() async {
        let transcripts = StartupTranscriptRecoveryStore(
            scan: TranscriptRecoveryScan(
                candidates: [],
                issues: [
                    TranscriptRecoveryScanIssue(
                        code: .enumerationFailed,
                        sessionID: nil,
                        message: "无法扫描听抄稿目录。",
                        technicalDetail: "Injected directory read failure"
                    )
                ],
                didReachLimit: true
            ),
            calls: StartupRecoveryCallLog(),
            recoveryResult: .notRequired
        )
        let diagnostics = FakeDiagnosticsRecorder()

        let report = await InterruptedSessionRecoveryCoordinator(
            transcripts: transcripts,
            recordings: StartupRecordingRecoveryStore(calls: StartupRecoveryCallLog()),
            recovery: FakeUtteranceRecoveryStore(),
            diagnostics: diagnostics
        ).recover()

        #expect(report.didReachLimit)
        #expect(report.issues.count == 2)
        #expect(await diagnostics.recordedEvents().count == 2)
    }
}
