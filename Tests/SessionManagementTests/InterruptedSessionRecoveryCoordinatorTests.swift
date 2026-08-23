import AudioCaptureAPI
import DiagnosticsAPI
import Foundation
import PersistenceAPI
import RecordingAPI
import SessionManagement
import Testing
import UtteranceRecoveryAPI

@Suite struct InterruptedRecoveryCoordinatorTests {
    @Test func repairsCAFBeforeCommittingTheTranscriptRecovery() async {
        let fixture = InterruptedRecoveryFixture.successful()
        let diagnostics = FakeDiagnosticsRecorder()

        let report = await InterruptedSessionRecoveryCoordinator(
            transcripts: fixture.transcripts,
            recordings: fixture.recordings,
            recovery: FakeUtteranceRecoveryStore(),
            diagnostics: diagnostics
        ).recover()

        #expect(await fixture.calls.values() == ["recording", "transcript"])
        #expect(report.repairedRecordingCount == 1)
        #expect(report.recoveredTranscriptCount == 1)
        #expect(report.issues.isEmpty)
        #expect(await diagnostics.recordedEvents().count == 2)
    }

    @Test func recordingFailureLeavesTranscriptUncommittedAndEntersDiagnostics() async {
        let fixture = InterruptedRecoveryFixture.recordingFailure()
        let diagnostics = FakeDiagnosticsRecorder()

        let report = await InterruptedSessionRecoveryCoordinator(
            transcripts: fixture.transcripts,
            recordings: fixture.recordings,
            recovery: FakeUtteranceRecoveryStore(),
            diagnostics: diagnostics
        ).recover()

        #expect(await fixture.calls.values() == ["recording"])
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
