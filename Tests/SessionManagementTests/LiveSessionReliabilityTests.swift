import AudioCaptureAPI
import Foundation
@testable import SessionManagement
import SessionManagementAPI
import Testing
import TranscriptAPI
import VADAPI

@Suite struct LiveSessionReliabilityTests {
    @Test func stopDuringPreparationCannotReenterListening() async throws {
        let harness = SessionTestHarness(modelPreparationDelay: .seconds(30))
        let startTask = Task { await harness.coordinator.start(inputDeviceID: nil) }
        try await waitUntil { !(await harness.downloader.requestedDescriptors()).isEmpty }

        await harness.coordinator.stop()
        await startTask.value

        let stopped = await harness.coordinator.currentSnapshot()
        #expect(stopped.phase == .idle)
        #expect(stopped.finalizationOutcome == .cancelledBeforeCapture)
        #expect((await harness.capture.capturedRequests()).isEmpty)
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

    @Test func modelLoadFailureIsTypedAndNeverStartsCapture() async throws {
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
        #expect(snapshot.finalizationOutcome == .failedBeforeCapture)
        #expect((await harness.capture.capturedRequests()).isEmpty)
    }

    @Test func recognitionFailureRetainsAudioAndReportsTypedIssue() async throws {
        let harness = SessionTestHarness(recognitionFails: true)

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.issues.first?.stage == .recognition)
        #expect(snapshot.issues.first?.utteranceSequence == 1)
        #expect(snapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        let pending = await harness.coordinator.pendingUtterances
        #expect(pending.first?.segment.samples == SessionTestHarness.audioFrame.samples)
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

    @Test func nextStartReplaysCrashStagedAudioBeforeListening() async throws {
        let harness = SessionTestHarness()
        let priorSessionID = UUID()
        await harness.store.begin(
            TranscriptSession(
                id: priorSessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
        let segment = SpeechSegment(
            sequenceNumber: 7,
            samples: SessionTestHarness.audioFrame.samples,
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
        _ = await harness.recoveryStore.stage(segment, for: priorSessionID)

        _ = try await harness.run()

        #expect((await harness.translator.receivedRequests()).count == 2)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).count == 2)
        #expect((await harness.store.finishedSessions()).contains { $0.id == priorSessionID })
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw SessionEventWaitError.timedOut
    }
}
