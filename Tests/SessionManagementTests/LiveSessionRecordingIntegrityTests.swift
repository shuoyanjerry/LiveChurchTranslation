import AudioCaptureAPI
import PersistenceAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct LiveSessionRecordingIntegrityTests {
    @Test func slowRecordingWriterCannotBackpressureCaptureOrRealtimeAnalysis() async throws {
        let frameCount = 160
        let frames = (0..<frameCount).map { index in
            AudioFrame(
                samples: Array(repeating: Float(index) / Float(frameCount), count: 320),
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(index * 20)
            )
        }
        let harness = SessionTestHarness(
            recordingAppendDelay: .milliseconds(20),
            holdsCaptureOpen: true,
            audioFrames: frames
        )

        await harness.coordinator.start(inputDeviceID: nil)
        try await waitUntil { await harness.processor.frames().count == frameCount }

        let recordingCountWhileAnalysisIsCurrent =
            await harness.recordingStore.recordedFrames().count
        #expect(recordingCountWhileAnalysisIsCurrent < frameCount)

        await harness.coordinator.stop()

        let recorded = await harness.recordingStore.recordedFrames()
        #expect(recorded == frames)
        #expect(await harness.processor.frames() == frames)
        #expect(await harness.recordingStore.completedSessionCount() == 1)
    }

    @Test func slowRealtimeAnalysisCannotTruncateRecording() async throws {
        let frameCount = 160
        let frames = (0..<frameCount).map { index in
            AudioFrame(
                samples: Array(repeating: Float(index) / Float(frameCount), count: 320),
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(index * 20)
            )
        }
        let harness = SessionTestHarness(
            audioProcessingDelay: .milliseconds(20),
            holdsCaptureOpen: true,
            audioFrames: frames
        )

        await harness.coordinator.start(inputDeviceID: nil)
        try await waitUntil { await harness.recordingStore.recordedFrames().count == frameCount }

        #expect(await harness.processor.frames().count < frameCount)

        await harness.coordinator.stop()

        #expect(await harness.recordingStore.recordedFrames() == frames)
        #expect(await harness.processor.frames() == frames)
        #expect(await harness.recordingStore.completedSessionCount() == 1)
    }

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
        guard case .savedWithIncompleteTranscript(let rejected, _) = snapshot.finalizationOutcome
        else {
            Issue.record("Expected the partial recording to retain an incomplete transcript")
            return
        }
        #expect(rejected == 0)
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
