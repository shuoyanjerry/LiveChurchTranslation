import AudioCaptureAPI
@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct UtteranceFailureIsolationTests {
    @Test func outputWithoutSafeTranslationStaysPendingAndContinuesLive() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["第一句。", "第二句。"],
            translationRejectsFirstOutput: true,
            emitsEveryFrame: true,
            audioFrames: pairedFrames()
        )

        let events = try await harness.run()

        await verifyLiveContinuation(harness, events: events)
        await verifyIncompleteOutcome(harness, events: events)
    }

    private func verifyLiveContinuation(
        _ harness: SessionTestHarness,
        events: [LiveSessionEvent]
    ) async {
        #expect((await harness.asr.receivedRequests()).count == 2)
        let translations = await harness.translator.receivedRequests()
        #expect(translations.map(\.sourceText) == ["第一句。", "第二句。"])
        #expect(translations[1].context.isEmpty)
        #expect((await harness.store.persistedEntries()).map(\.sourceText) == ["第二句。"])
        #expect((await harness.recoveryStore.pendingRecords()).map(\.id.sequenceNumber) == [1])
        #expect((await harness.recoveryStore.completedIDs()).map(\.sequenceNumber) == [2])
        let rejected = await harness.recoveryStore.terminalRejections()
        #expect(rejected.isEmpty)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
        #expect(events.recoverableErrors.count == 1)
    }

    private func verifyIncompleteOutcome(
        _ harness: SessionTestHarness,
        events: [LiveSessionEvent]
    ) async {
        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.stage == .translation)
        #expect(snapshot.issues.first?.isRecoverable == true)
        #expect(
            snapshot.finalizationOutcome
                == .savedWithIncompleteTranscript(
                    rejectedUtteranceCount: 0,
                    recoverableUtteranceCount: 1
                )
        )
    }

    @Test func retryableMiddleSentenceDoesNotBlockLaterSentenceOrPolluteContext() async throws {
        let harness = SessionTestHarness(
            recognizedText: "第一句。第二句。第三句。",
            translationRejectedRequestIndices: [1]
        )

        _ = try await harness.run()

        let translations = await harness.translator.receivedRequests()
        #expect(translations.map(\.sourceText) == ["第一句。", "第二句。", "第三句。"])
        #expect(translations[0].context.isEmpty)
        #expect(translations[1].context.map(\.sourceText) == ["第一句。"])
        #expect(translations[2].context.map(\.sourceText) == ["第一句。"])
        #expect(
            (await harness.store.persistedEntries()).map(\.sourceText)
                == ["第一句。", "第三句。"]
        )
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
        let rejected = await harness.recoveryStore.terminalRejections()
        #expect(rejected.isEmpty)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
    }

    @Test func reviewedTranslationIsDisplayedPersistedAndDoesNotMarkSessionIncomplete() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["第一句。", "第二句。"],
            translationReviewedRequestIndices: [0],
            emitsEveryFrame: true,
            audioFrames: pairedFrames()
        )

        let events = try await harness.run()

        let translations = await harness.translator.receivedRequests()
        #expect(translations.count == 2)
        #expect(translations[1].context.isEmpty)
        let entries = await harness.store.persistedEntries()
        #expect(entries.map(\.sourceText) == ["第一句。", "第二句。"])
        #expect(entries[0].translationReview?.issueCodes == ["quality.missing_required_term"])
        #expect(entries[1].translationReview == nil)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.terminalRejections()).isEmpty)
        #expect(await harness.coordinator.currentSnapshot().issues.isEmpty)
        #expect(events.recoverableErrors.isEmpty)
    }

    @Test func hallucinatedRecognitionIsRejectedWithoutBlockingTheNextSegment() async throws {
        let harness = SessionTestHarness(
            recognitionErrorsByIndex: [0: .promptOnlyHallucination],
            emitsEveryFrame: true,
            audioFrames: pairedFrames()
        )

        _ = try await harness.run()

        #expect((await harness.asr.receivedRequests()).count == 2)
        #expect((await harness.translator.receivedRequests()).count == 1)
        #expect((await harness.store.persistedEntries()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        let rejected = await harness.recoveryStore.terminalRejections()
        #expect(rejected.map { $0.0.sequenceNumber } == [1])
        #expect(rejected.first?.1.map(\.failureCode) == ["asr.prompt_only_hallucination"])
        #expect(await harness.coordinator.diskRecoveryMode == nil)
    }

    private func pairedFrames() -> [AudioFrame] {
        (0..<2).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
    }
}
