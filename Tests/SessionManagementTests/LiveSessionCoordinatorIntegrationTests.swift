import AudioCaptureAPI
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

        let recognitionRequests = await harness.asr.receivedRequests()
        let recognition = try #require(recognitionRequests.first)
        #expect(recognitionRequests.count == 1)
        #expect(recognition.segment.samples.count == 320)
        #expect(recognition.contextPrompt.contains("因信称义"))
        #expect(recognition.contextPrompt.contains("恩典"))
        #expect(!recognition.contextPrompt.contains("我们"))

        let translationRequests = await harness.translator.receivedRequests()
        let translation = try #require(translationRequests.first)
        #expect(translationRequests.count == 1)
        #expect(
            translation.glossary == [
                TranslationTerm(source: "因信称义", target: "justification by faith"),
                TranslationTerm(source: "恩典", target: "grace"),
            ]
        )

        #expect(await harness.store.persistedEntries() == [published])
        #expect(await harness.store.attemptedAppendCount() == 1)
        #expect((await harness.store.finishedSessions()).count == 1)
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
        #expect((await harness.asr.receivedRequests()).isEmpty)
        let snapshot = await harness.coordinator.currentSnapshot()
        guard case .failed(let message) = snapshot.phase else {
            Issue.record("Expected permission denial to fail the session")
            return
        }
        #expect(message.contains("not authorized"))
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
    }

    @Test func observedQwenErrorsAreNormalizedBeforeTranslationAndPersistence() async throws {
        let raw = "休恩、恩典、因信生义、圣灵，并在圣灵里承受。"
        let expected = "救恩、恩典、因信称义、圣灵，并在圣灵里成圣。"
        let harness = SessionTestHarness(recognizedText: raw)

        let events = try await harness.run()

        #expect(events.appendedEntries.first?.sourceText == expected)
        #expect(await harness.translator.receivedRequests().first?.sourceText == expected)
        #expect(await harness.store.persistedEntries().first?.sourceText == expected)
    }

    @Test func glossaryRecognitionAliasIsNormalizedBeforeTermMatching() async throws {
        let harness = SessionTestHarness(recognizedText: "我们领受喜礼。")

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        #expect(request.sourceText == "我们领受洗礼。")
        #expect(request.glossary.contains(TranslationTerm(source: "洗礼", target: "baptism")))
    }
}
