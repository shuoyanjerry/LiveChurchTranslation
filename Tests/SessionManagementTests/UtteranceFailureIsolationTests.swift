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
        await verifyRecoverableOutcome(harness)
    }

    private func verifyLiveContinuation(
        _ harness: SessionTestHarness,
        events: [LiveSessionEvent]
    ) async {
        #expect((await harness.asr.receivedRequests()).count == 2)
        let translations = await harness.translator.receivedRequests()
        #expect(translations.map(\.sourceText) == ["第一句。", "第二句。"])
        #expect(translations[1].context.isEmpty)
        #expect((await harness.store.appendedEntries()).map(\.sourceText) == ["第二句。"])
        #expect((await harness.recoveryStore.pendingRecords()).map(\.id.sequenceNumber) == [1])
        #expect((await harness.recoveryStore.completedIDs()).map(\.sequenceNumber) == [2])
        let rejected = await harness.recoveryStore.terminalRejections()
        #expect(rejected.isEmpty)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
        #expect(events.recoverableErrors.count == 1)
    }

    private func verifyRecoverableOutcome(_ harness: SessionTestHarness) async {
        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.issues.count == 1)
        #expect(snapshot.issues.first?.stage == .translation)
        #expect(snapshot.issues.first?.isRecoverable == true)
        #expect(snapshot.phase == .idle)
        #expect(snapshot.statusMessage == "听抄稿已保存，仍有 1 段待恢复")
        #expect(snapshot.finalizationOutcome == .savedWithUnresolvedUtterances(count: 1))
    }

    @Test func multiSentenceSegmentRetriesAsOneAtomicTranslation() async throws {
        let source = "第一句。第二句。第三句。"
        let harness = SessionTestHarness(
            recognizedText: source,
            translationRejectedRequestIndices: [0]
        )

        _ = try await harness.run()

        let translations = await harness.translator.receivedRequests()
        #expect(translations.map(\.sourceText) == [source])
        #expect(translations[0].context.isEmpty)
        #expect((await harness.store.appendedEntries()).isEmpty)
        #expect((await harness.recoveryStore.pendingRecords()).count == 1)
        let rejected = await harness.recoveryStore.terminalRejections()
        #expect(rejected.isEmpty)
        #expect(await harness.coordinator.diskRecoveryMode == nil)
    }

    @Test func reviewedTranslationIsDisplayedAfterSourceCommitWithoutIncompleteState() async throws {
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
        let entries = await harness.store.appendedEntries()
        #expect(entries.map(\.sourceText) == ["第一句。", "第二句。"])
        #expect(entries[0].translationReview?.issueCodes == ["quality.pronoun_alignment"])
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
        #expect((await harness.store.appendedEntries()).count == 1)
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
