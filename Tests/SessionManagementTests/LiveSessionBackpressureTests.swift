import AudioCaptureAPI
import Foundation
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct LiveSessionBackpressureTests {
    @Test func overloadKeepsRecordingAndDefersAContiguousTailToDisk() async throws {
        let frames = (0..<40).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
        let harness = SessionTestHarness(
            recognitionDelay: .milliseconds(100),
            emitsEveryFrame: true,
            audioFrames: frames
        )

        let events = try await harness.run()

        let recorded = await harness.recordingStore.recordedFrames()
        let completed = await harness.recoveryStore.completedIDs()
        let pending = await harness.recoveryStore.pendingRecords()
        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(recorded == frames)
        #expect(completed.count + pending.count == frames.count)
        #expect(!pending.isEmpty)
        #expect((await harness.asr.receivedRequests()).count <= 1)
        #expect(events.recoverableErrors.contains { $0.contains("保存到磁盘") })
        #expect(snapshot.issues.contains { $0.message.contains("会议完整录音") })
        #expect(snapshot.statusMessage.contains("句等待恢复"))
        #expect(
            snapshot.finalizationOutcome
                == .savedWithUnresolvedUtterances(count: pending.count)
        )
        #expect(await harness.coordinator.segmentQueue.isEmpty)
        #expect(await harness.coordinator.unresolvedUtteranceCount == pending.count)
        let completedPrefix = (0..<completed.count).map { UInt64($0 + 1) }
        #expect(completed.map(\.sequenceNumber).sorted() == completedPrefix)
    }

    @Test func recoveryStageFailureRetainsFullRecordingAndNamesManualRetry() async throws {
        let harness = SessionTestHarness(recoveryStageFails: true)

        let events = try await harness.run()

        #expect((await harness.recordingStore.recordedFrames()) == [SessionTestHarness.audioFrame])
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(await harness.coordinator.unresolvedUtteranceCount == 1)
        #expect(
            (await harness.coordinator.currentSnapshot()).finalizationOutcome
                == .savedWithUnresolvedUtterances(count: 1)
        )
        let statuses = events.compactMap { event -> String? in
            guard case .stateChanged(let snapshot) = event else { return nil }
            return snapshot.statusMessage
        }
        #expect(statuses.contains { $0.contains("会议录音重试") })
    }

    @Test func firstInferenceFailureDefersLaterAudioWithoutRetryStorm() async throws {
        let frames = (0..<40).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
        let harness = SessionTestHarness(
            recognitionFails: true,
            holdsCaptureOpen: true,
            emitsEveryFrame: true,
            audioFrames: [frames[0]]
        )

        await harness.coordinator.start(inputDeviceID: nil)
        try await waitUntil { await harness.asr.receivedRequests().count == 1 }
        for frame in frames.dropFirst() {
            await harness.capture.emit(frame)
        }
        await harness.coordinator.stop()

        #expect((await harness.recordingStore.recordedFrames()) == frames)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).count == frames.count)
        #expect(await harness.coordinator.unresolvedUtteranceCount == frames.count)
        #expect(await harness.coordinator.pendingUtterances.count == 1)
        #expect((await harness.coordinator.currentSnapshot()).issues.count == 1)
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
