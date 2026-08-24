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
        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect(await harness.translator.loadCount() == 0)
        #expect(await harness.translator.runtimeCheckCount() == 0)
        let entries = await harness.store.appendedEntries()
        #expect(entries.count == frames.count)
        #expect(entries.allSatisfy { $0.isSourceOnly })
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

    @Test func unavailableTranslationRuntimeDoesNotAffectImport() async throws {
        let frames = Self.frames(count: 3)
        let harness = SessionTestHarness(
            translationFails: true,
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run()

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.finalizationOutcome == .saved)
        #expect((await harness.asr.receivedRequests()).count == frames.count)
        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect(await harness.translator.loadCount() == 0)
        #expect(await harness.translator.runtimeCheckCount() == 0)
        #expect((await harness.store.appendedEntries()).allSatisfy { $0.isSourceOnly })
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.terminalRejections()).isEmpty)
        #expect((await harness.recordingStore.recordedFrames()) == frames)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
        let finalization = try #require(await harness.store.transcriptFinalizations().last)
        #expect(finalization.integrity == .complete)
        #expect(finalization.pendingRecordCount == 0)
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
    @Test func everyImportedSegmentCommitsOnlyRecognizedSource() async throws {
        let frames = Self.frames(count: 2)
        let harness = SessionTestHarness(
            recognizedTexts: ["第一句。", "第二句。"],
            emitsEveryFrame: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run()

        #expect((await harness.translator.receivedRequests()).isEmpty)
        let entries = await harness.store.appendedEntries()
        #expect(entries.count == 2)
        #expect(entries.map(\.sourceText) == ["第一句。", "第二句。"])
        #expect(entries.allSatisfy { $0.isSourceOnly })
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(await harness.coordinator.currentSnapshot().finalizationOutcome == .saved)
    }

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

extension TranscriptEntry {
    fileprivate var isSourceOnly: Bool {
        targetText.isEmpty && translationReview == nil && translationMilliseconds == 0
    }
}
