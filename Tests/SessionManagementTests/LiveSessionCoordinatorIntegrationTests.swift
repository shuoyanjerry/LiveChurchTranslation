import AudioCaptureAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing
import TranslationAPI

@Suite struct LiveSessionCoordinatorIntegrationTests {
    @Test func audioFrameFlowsThroughPipelineAndPublishesPersistedEntry() async throws {
        let harness = SessionTestHarness()

        let events = try await harness.run()

        let published = try #require(events.appendedEntries.first)
        #expect(events.appendedEntries.count == 1)
        #expect(published.sourceText == "我们因信称义，这是恩典。")
        #expect(published.targetText == "We are justified by faith; this is grace.")
        #expect((await harness.capture.capturedRequests()).count == 1)
        #expect((await harness.processor.frames()).count == 1)
        #expect((await harness.vad.frames()).count == 1)
        #expect((await harness.recordingStore.recordedFrames()) == [SessionTestHarness.audioFrame])
        #expect((await harness.recordingStore.completedSessionCount()) == 1)

        try await verifyRecognitionRequest(from: harness)
        try await verifyTranslationRequest(from: harness)

        #expect(await harness.store.persistedEntries() == [published])
        #expect(await harness.store.attemptedAppendCount() == 1)
        #expect((await harness.store.finishedSessions()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).count == 1)
        #expect((await harness.downloader.requestedDescriptors()).count == 2)
        let bufferSnapshot = try #require(await harness.transcript.snapshot())
        #expect(bufferSnapshot.entries == [published])
        let controllerSnapshot = await harness.coordinator.currentSnapshot()
        #expect(controllerSnapshot.phase == .idle)
        #expect(controllerSnapshot.transcript == [published])
    }

    @Test func permissionDenialNeverStartsOrPublishesPipeline() async throws {
        let harness = SessionTestHarness(permission: .denied)

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect((await harness.capture.capturedRequests()).isEmpty)
        #expect((await harness.downloader.requestedDescriptors()).isEmpty)
        #expect((await harness.store.begunSessions()).isEmpty)
        #expect((await harness.recordingStore.recordedFrames()).isEmpty)
        #expect((await harness.asr.receivedRequests()).isEmpty)
        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected permission denial to fail the session")
            return
        }
        #expect(message == "尚未允许麦克风访问。")
        #expect(snapshot.transcript.isEmpty)
    }

    @Test func translationFailureDoesNotPublishOrPersistEntry() async throws {
        let harness = SessionTestHarness(translationFails: true)

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect(
            events.recoverableErrors.contains {
                $0.contains("fake translation runtime failed")
            })
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect(await harness.store.attemptedAppendCount() == 0)
        #expect((await harness.store.persistedEntries()).isEmpty)
        let bufferSnapshot = try #require(await harness.transcript.snapshot())
        #expect(bufferSnapshot.entries.isEmpty)
        let controllerSnapshot = await harness.coordinator.currentSnapshot()
        #expect(controllerSnapshot.transcript.isEmpty)
        #expect(controllerSnapshot.issues.count == 1)
        #expect(controllerSnapshot.issues.first?.stage == .translation)
        #expect(controllerSnapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        let pending = await harness.coordinator.pendingUtterances
        #expect(pending.count == 1)
        #expect(pending.first?.sampleCount == 320)
        #expect(pending.first?.translatedEntry == nil)
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
    }

    @Test func storageFailureDoesNotPublishEntryToBufferOrController() async throws {
        let harness = SessionTestHarness(storageFails: true)

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect(
            events.recoverableErrors.contains {
                $0.contains("fake transcript store failed")
            })
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect(await harness.store.attemptedAppendCount() == 1)
        #expect((await harness.store.persistedEntries()).isEmpty)
        let bufferSnapshot = try #require(await harness.transcript.snapshot())
        #expect(bufferSnapshot.entries.isEmpty)
        let controllerSnapshot = await harness.coordinator.currentSnapshot()
        #expect(controllerSnapshot.transcript.isEmpty)
        #expect(controllerSnapshot.issues.first?.stage == .persistence)
        #expect(controllerSnapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
        let pending = await harness.coordinator.pendingUtterances
        #expect(pending.count == 1)
        #expect(pending.first?.translatedEntry?.targetText == "We are justified by faith; this is grace.")
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
    }

}

extension LiveSessionCoordinatorIntegrationTests {
    @Test func promptEchoIsTerminallyRejectedWithoutPublishingOrRetrying() async throws {
        let harness = SessionTestHarness(recognitionError: .promptOnlyHallucination)

        let events = try await harness.run()

        #expect(events.appendedEntries.isEmpty)
        #expect(events.recoverableErrors.isEmpty)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).isEmpty)
        let rejections = await harness.recoveryStore.terminalRejections()
        #expect(rejections.count == 1)
        #expect(rejections.first?.0.sequenceNumber == 1)
        #expect(rejections.first?.1.count == 1)
        #expect(rejections.first?.1.first?.sentenceOrdinal == 0)
        #expect(rejections.first?.1.first?.stage == .recognition)
        #expect(rejections.first?.1.first?.failureCode == "asr.prompt_only_hallucination")
        #expect((await harness.store.persistedEntries()).isEmpty)
        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.phase == .idle)
        #expect(snapshot.statusMessage == "听抄稿已保存，其中 1 段未通过质量校验")
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.stage == .recognition)
        #expect(snapshot.issues.first?.utteranceSequence == 1)
        #expect(snapshot.issues.first?.message == "识别结果仅包含提示词，已拒绝该片段。")
        #expect(snapshot.issues.first?.isRecoverable == false)
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 1,
                    recoverableUtteranceCount: 0
                )
        )
    }

    @Test func observedQwenErrorsAreNormalizedBeforeTranslationAndPersistence() async throws {
        let raw = "休恩、恩典、因信生义、圣灵，并在圣灵里承受。"
        let expected = "救恩、恩典、因信称义、圣灵，并在圣灵里承受。"
        let harness = SessionTestHarness(recognizedText: raw)

        let events = try await harness.run()

        #expect(events.appendedEntries.first?.sourceText == expected)
        #expect(events.appendedEntries.first?.rawSourceText == raw)
        #expect(events.appendedEntries.first?.sourceCorrections.count == 2)
        #expect(await harness.translator.receivedRequests().first?.sourceText == expected)
        #expect(await harness.store.persistedEntries().first?.sourceText == expected)
    }

    @Test func glossaryRecognitionAliasIsNormalizedBeforeTermMatching() async throws {
        let harness = SessionTestHarness(recognizedText: "我们领受喜礼。")

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        #expect(request.sourceText == "我们领受洗礼。")
        #expect(
            request.glossary.contains(
                TranslationTerm(
                    source: "洗礼",
                    target: "baptism",
                    requirement: .preferred
                )
            )
        )
    }
}
