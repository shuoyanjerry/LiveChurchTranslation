import AudioCaptureAPI
import Foundation
@testable import SessionManagement
import SessionManagementAPI
import Testing
import TranscriptAPI

@Suite struct ImportedAudioCompletenessTests {
    @Test func fastFileCaptureWaitsForEverySegmentToFinish() async throws {
        let frames = Self.frames(count: 40)
        let harness = SessionTestHarness(
            recognitionDelay: .milliseconds(20),
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run(timeout: .seconds(15))

        #expect((await harness.asr.receivedRequests()).count == frames.count)
        #expect((await harness.translator.receivedRequests()).count == frames.count)
        #expect((await harness.store.persistedEntries()).count == frames.count)
        #expect((await harness.recoveryStore.completedIDs()).count == frames.count)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.coordinator.currentSnapshot()).finalizationOutcome == .saved)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
        #expect(await harness.coordinator.segmentQueue.isEmpty)
    }

    @Test func inferenceFailureMakesImportExplicitlyFailedAndRecoverable() async throws {
        let frames = Self.frames(count: 40)
        let harness = SessionTestHarness(
            recognitionFails: true,
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected an incomplete import to fail explicitly")
            return
        }
        #expect(message.contains("音频听抄未完成"))
        #expect(snapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 40))
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).count == frames.count)
        #expect((await harness.recordingStore.recordedFrames()) == frames)
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.integrity == .incomplete)
        #expect(finalization.pendingRecordCount == frames.count)
    }

    @Test func missingSafeOutputContinuesWholeImportAndRemainsRecoverable() async throws {
        let frames = Self.frames(count: 3)
        let harness = SessionTestHarness(
            translationRejectsFirstOutput: true,
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected the recoverable import to be incomplete")
            return
        }
        #expect(message.contains("听抄不完整"))
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 0,
                    recoverableUtteranceCount: 1
                )
        )
        #expect((await harness.asr.receivedRequests()).count == frames.count)
        #expect((await harness.translator.receivedRequests()).count == frames.count)
        #expect((await harness.store.persistedEntries()).count == frames.count - 1)
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
        #expect((await harness.recoveryStore.terminalRejections()).isEmpty)
        #expect((await harness.recordingStore.recordedFrames()) == frames)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.integrity == .incomplete)
        #expect(finalization.pendingRecordCount == 1)
        #expect(finalization.rejections.isEmpty)
    }

    @Test func recoveryStoreFailureRequiresOriginalFileRetry() async throws {
        let frames = Self.frames(count: 40)
        let harness = SessionTestHarness(
            recoveryStageFails: true,
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected an import without durable segments to fail explicitly")
            return
        }
        #expect(message.contains("重新处理原始文件"))
        #expect((await harness.asr.receivedRequests()).isEmpty)
        #expect(await harness.recoveryStore.stageAttemptCount() == 1)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recordingStore.recordedFrames()) == frames)
    }

    @Test func stoppingBeforeEndNeverReportsACompleteImport() async throws {
        let harness = SessionTestHarness(
            holdsCaptureOpen: true,
            emitsEveryFrame: true,
            audioFrames: [],
            sessionKind: .importedAudio
        )

        await harness.coordinator.start(inputDeviceID: nil)
        await harness.coordinator.stop()

        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected a stopped import to fail explicitly")
            return
        }
        #expect(message.contains("完整听抄前中断"))
    }

}

extension ImportedAudioCompletenessTests {
    fileprivate static func frames(count: Int) -> [AudioFrame] {
        (0..<count).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
    }
}
