import ASRAPI
import PersistenceAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite("No silent omission after durable staging")
struct NoSilentOmissionTests {
    @Test("ASR-filtered speech is terminally rejected instead of ignored")
    func filteredSpeechRetainsTerminalEvidence() async throws {
        let harness = SessionTestHarness(recognitionError: .filteredNonspeech)

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect(events.recoverableErrors.isEmpty)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).isEmpty)
        let rejection = try #require(await harness.recoveryStore.terminalRejections().first)
        #expect(rejection.0.sequenceNumber == 1)
        #expect(rejection.1.map(\.failureCode) == ["asr.filtered_nonspeech"])
        #expect(rejection.1.allSatisfy { $0.stage == .recognition })

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.transcript.isEmpty)
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.isRecoverable == false)
        #expect(snapshot.issues.allSatisfy { !$0.message.contains("asr.") })
        #expect((await harness.recordingStore.recordedFrames()) == [SessionTestHarness.audioFrame])
        #expect(await harness.recordingStore.completedSessionCount() == 1)
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.integrity == .incomplete)
        #expect(finalization.rejections.map(\.failureCode) == ["asr.filtered_nonspeech"])
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 1,
                    recoverableUtteranceCount: 0
                )
        )
    }

    @Test("Whitespace-only recognition receives a stable terminal code")
    func nonprocessableRecognitionRetainsTerminalEvidence() async throws {
        let harness = SessionTestHarness(recognizedText: " \n\t ")

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect(events.recoverableErrors.isEmpty)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).isEmpty)
        let rejection = try #require(await harness.recoveryStore.terminalRejections().first)
        #expect(rejection.1.map(\.failureCode) == ["asr.no_processable_sentences"])

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.transcript.isEmpty)
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.integrity == .incomplete)
        #expect(finalization.rejections.map(\.failureCode) == ["asr.no_processable_sentences"])
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 1,
                    recoverableUtteranceCount: 0
                )
        )
    }
}
