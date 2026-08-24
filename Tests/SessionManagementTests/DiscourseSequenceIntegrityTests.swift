import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

@Suite struct DiscourseSequenceIntegrityTests {
    @Test func recoveryExcludesFutureSourceDespiteDensePresentationOrder() async throws {
        let harness = SessionTestHarness(recognizedText: "他继续分享。")
        let sessionID = UUID()
        await beginPriorSession(harness, id: sessionID)
        await harness.store.seed(entry(sequence: 1, sourceSequence: 1, text: "这是先前的信息。"))
        await harness.store.seed(entry(sequence: 2, sourceSequence: 10, text: "那位姐妹作了见证。"))
        let pending = segment(sequence: 7)
        _ = try await harness.recoveryStore.stage(pending, for: sessionID)

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        #expect(request.context.map(\.sourceText) == ["这是先前的信息。"])
        let recovered = try #require(
            await harness.store.appendedEntries().first { $0.id == pending.id }
        )
        #expect(recovered.sourceText == "他继续分享。")
        #expect(recovered.sourceSegmentSequence == 7)
        #expect(recovered.sourcePronounDecisions.first?.resolution == .unresolvedSpokenMandarin)
        let finalized = try #require(
            await harness.store.finishedSessions().first { $0.id == sessionID }
        )
        #expect(finalized.entries.map(\.sequence) == [1, 2, 3])
        #expect(finalized.entries.compactMap(\.sourceSegmentSequence) == [1, 7, 10])
    }

    @Test func legacyEntryWithoutSourceIdentityIsNeverRecoveryEvidence() async throws {
        let harness = SessionTestHarness(recognizedText: "他继续分享。")
        let sessionID = UUID()
        await beginPriorSession(harness, id: sessionID)
        await harness.store.seed(
            entry(sequence: 1, sourceSequence: nil, text: "那位姐妹作了见证。")
        )
        let pending = segment(sequence: 7)
        _ = try await harness.recoveryStore.stage(pending, for: sessionID)

        _ = try await harness.run()

        let request = try #require(await harness.translator.receivedRequests().first)
        #expect(request.context.isEmpty)
        let recovered = try #require(
            await harness.store.appendedEntries().first { $0.id == pending.id }
        )
        #expect(recovered.sourceText == "他继续分享。")
        #expect(recovered.sourcePronounDecisions.first?.resolution == .unresolvedSpokenMandarin)
    }

    private func beginPriorSession(_ harness: SessionTestHarness, id: UUID) async {
        await harness.store.begin(
            TranscriptSession(
                id: id,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
    }

    private func entry(
        sequence: Int,
        sourceSequence: UInt64?,
        text: String
    ) -> TranscriptEntry {
        TranscriptEntry(
            sequence: sequence,
            sourceSegmentSequence: sourceSequence,
            sourceText: text,
            targetText: "context",
            startedMilliseconds: 0,
            endedMilliseconds: 1_000,
            translationMilliseconds: 10
        )
    }

    private func segment(sequence: UInt64) -> SpeechSegment {
        SpeechSegment(
            sequenceNumber: sequence,
            samples: SessionTestHarness.audioFrame.samples,
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
    }
}
