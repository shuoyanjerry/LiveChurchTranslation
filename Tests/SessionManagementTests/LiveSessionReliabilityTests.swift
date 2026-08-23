import AudioCaptureAPI
import Foundation
@testable import SessionManagement
import SessionManagementAPI
import Testing
import TranscriptAPI
import VADAPI

@Suite struct LiveSessionReliabilityTests {
    @Test func stopDuringPreparationPreservesEarlyRecordingAndCannotReenterListening() async throws {
        let harness = SessionTestHarness(modelPreparationDelay: .seconds(30))
        let startTask = Task { await harness.coordinator.start(inputDeviceID: nil) }
        try await waitUntil { !(await harness.downloader.requestedDescriptors()).isEmpty }

        let preparing = await harness.coordinator.currentSnapshot()
        #expect(preparing.phase == .preparingModel)
        #expect(preparing.captureStartedAt != nil)
        #expect(preparing.statusMessage.contains("Recording"))
        #expect((await harness.recordingStore.recordedFrames()).count == 1)

        await harness.coordinator.stop()
        await startTask.value

        let stopped = await harness.coordinator.currentSnapshot()
        #expect(stopped.phase == .idle)
        #expect(stopped.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        #expect((await harness.capture.capturedRequests()).count == 1)
        #expect(await harness.recordingStore.completedSessionCount() == 1)
        #expect(await harness.recordingStore.discardedSessionCount() == 0)
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
        #expect((await harness.recoveryStore.completedIDs()).isEmpty)
        #expect((await harness.downloader.cancelledDescriptors()).count == 2)
        try await Task.sleep(for: .milliseconds(20))
        #expect((await harness.coordinator.currentSnapshot()).phase == .idle)
    }

    @Test func stopDrainsCapturedTailBeforeFlushingVAD() async throws {
        let secondFrame = AudioFrame(
            samples: Array(repeating: 0.5, count: 320),
            sampleRate: 16_000,
            channelCount: 1,
            timestamp: .milliseconds(20)
        )
        let harness = SessionTestHarness(
            holdsCaptureOpen: true,
            emitsOnlyOnFlush: true,
            audioFrames: [SessionTestHarness.audioFrame, secondFrame]
        )

        await harness.coordinator.start(inputDeviceID: nil)
        await harness.coordinator.stop()

        let request = try #require(await harness.asr.receivedRequests().first)
        #expect(request.segment.samples.count == 640)
        #expect(request.segment.endReason == .endOfStream)
        #expect((await harness.processor.frames()).count == 2)
        #expect((await harness.store.persistedEntries()).count == 1)
        #expect((await harness.coordinator.currentSnapshot()).finalizationOutcome == .saved)
    }

    @Test func modelLoadFailureStopsButPreservesRecordingAndDurablePendingAudio() async throws {
        let harness = SessionTestHarness(modelLoadFails: true)

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected a failed session")
            return
        }
        #expect(message.contains("failed to load"))
        #expect(snapshot.issues.first?.stage == .preparation)
        #expect(snapshot.issues.first?.isRecoverable == true)
        #expect(snapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        #expect((await harness.capture.capturedRequests()).count == 1)
        #expect(await harness.recordingStore.completedSessionCount() == 1)
        #expect(await harness.recordingStore.discardedSessionCount() == 0)
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
        #expect((await harness.recoveryStore.completedIDs()).isEmpty)
    }

    @Test func currentSessionStagedDuringModelPreparationIsProcessedExactlyOnce() async throws {
        let harness = SessionTestHarness(
            modelPreparationDelay: .milliseconds(50),
            holdsCaptureOpen: true
        )

        await harness.coordinator.start(inputDeviceID: nil)
        try await waitUntil { (await harness.asr.receivedRequests()).count == 1 }

        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect((await harness.recoveryStore.completedIDs()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        await harness.coordinator.stop()
    }
}

extension LiveSessionReliabilityTests {
    @Test func recognitionFailureRetainsAudioAndReportsTypedIssue() async throws {
        let harness = SessionTestHarness(recognitionFails: true)

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.issues.first?.stage == .recognition)
        #expect(snapshot.issues.first?.utteranceSequence == 1)
        #expect(snapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        let pending = await harness.coordinator.pendingUtterances
        #expect(pending.first?.sampleCount == SessionTestHarness.audioFrame.samples.count)
        #expect(pending.first?.sequenceNumber == 1)
        #expect(pending.first?.translatedEntry == nil)
    }

    @Test func finalSaveFailureRetainsTranscriptAndReportsOutcome() async throws {
        let harness = SessionTestHarness(finishFails: true)

        let events = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .saveFailed(let message, let unresolved) = snapshot.finalizationOutcome else {
            Issue.record("Expected an explicit save failure")
            return
        }
        #expect(message.contains("could not be finalized"))
        #expect(unresolved == 0)
        #expect(snapshot.issues.last?.stage == .finalization)
        #expect(events.recoverableErrors.contains { $0.contains("could not be finalized") })
        #expect((await harness.coordinator.unsavedTranscripts).count == 1)
        #expect((await harness.store.finishedSessions()).isEmpty)
    }

    @Test func recordingFinishFailureRepairsInsteadOfDiscardingAudio() async throws {
        let harness = SessionTestHarness(recordingFinishFails: true)

        _ = try await harness.run()

        #expect(await harness.recordingStore.repairedSessionCount() == 1)
        #expect(await harness.recordingStore.discardedSessionCount() == 0)
        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.phase == .idle)
        #expect(snapshot.finalizationOutcome == .saved)
        #expect(snapshot.issues.contains { $0.message.contains("recording was recovered") })
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
        #expect(snapshot.finalizationOutcome == .saved)
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
        #expect(message.contains("recoverable partial form"))
    }
}
