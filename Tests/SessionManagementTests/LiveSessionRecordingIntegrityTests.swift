import PersistenceAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct LiveSessionRecordingIntegrityTests {
    @Test func recordingAppendFailureRepairsPartialAndNeverDiscardsIt() async throws {
        let harness = SessionTestHarness(recordingAppendFails: true)

        _ = try await harness.run()

        #expect(await harness.recordingStore.repairedSessionCount() == 1)
        #expect(await harness.recordingStore.discardedSessionCount() == 0)
        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected the interrupted live capture to be reported as failed")
            return
        }
        #expect(message.contains("Injected write interruption"))
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 0,
                    recoverableUtteranceCount: 0
                )
        )
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.hasUnrecoverableFailure)
        #expect(finalization.integrity == .incomplete)
    }

    @Test func unrepairedRecordingFailureStillRetainsPartialArtifact() async throws {
        let harness = SessionTestHarness(
            recordingFinishFails: true,
            recordingRepairFails: true
        )

        _ = try await harness.run()

        #expect(await harness.recordingStore.repairedSessionCount() == 0)
        #expect(await harness.recordingStore.discardedSessionCount() == 0)
        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected an unrepaired recording to fail explicitly")
            return
        }
        #expect(message.contains("可恢复的未完成状态"))
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 0,
                    recoverableUtteranceCount: 0
                )
        )
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.hasUnrecoverableFailure)
        #expect(finalization.integrity == .incomplete)
    }
}
