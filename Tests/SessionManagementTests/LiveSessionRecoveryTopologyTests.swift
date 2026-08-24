import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

extension LiveSessionRecoveryReliabilityTests {
    @Test func legacyRecoveryHandlesMissingFirstSentenceWithoutPublishingWholeSegment() async throws {
        let source = "Grace saves us. Christ is Lord. We pray."
        let harness = SessionTestHarness(
            recognizedTexts: [source, "A new segment."],
            translationMode: .englishToSimplifiedChinese
        )
        let sessionID = UUID()
        await harness.store.begin(priorSession(id: sessionID))
        let segment = recoverySegment()
        await harness.store.seed(
            TranscriptEntry(
                id: SentenceEntryIdentity.make(sourceSegmentID: segment.id, ordinal: 1),
                sequence: 2,
                sourceSegmentSequence: 7,
                sourceText: "Christ is Lord.",
                targetText: "基督是主。",
                startedMilliseconds: 7,
                endedMilliseconds: 14,
                translationMilliseconds: 10
            )
        )
        _ = try await harness.recoveryStore.stageLegacySentenceEntries(
            segment,
            for: sessionID
        )

        _ = try await harness.run()

        let requests = await harness.translator.receivedRequests()
        #expect(requests.map(\.sourceText) == ["Grace saves us.", "We pray.", "A new segment."])
        #expect(!requests.contains { $0.sourceText == source })
        let prior = try #require(
            await harness.store.finishedSessions().first { $0.id == sessionID }
        )
        #expect(
            prior.entries.map(\.sourceText)
                == ["Grace saves us.", "Christ is Lord.", "We pray."]
        )
    }

    @Test func segmentTopologyNeverFallsBackToLegacySplittingWhenRecognitionDrifts() async throws {
        try await expectAtomicRecoveryDespiteRecognitionDrift(unversionedV1: false)
    }

    @Test func schemaOneAtomicEntryIsNotMistakenForSplitRecovery() async throws {
        try await expectAtomicRecoveryDespiteRecognitionDrift(unversionedV1: true)
    }

    @Test func schemaOneWithoutPartialOutputUpgradesToAtomicSegment() async throws {
        let source = "Grace saves us. Christ is Lord."
        let harness = SessionTestHarness(
            recognizedTexts: [source, "A new segment."],
            translationMode: .englishToSimplifiedChinese
        )
        let sessionID = UUID()
        await harness.store.begin(priorSession(id: sessionID))
        _ = try await harness.recoveryStore.stageLegacySentenceEntries(
            recoverySegment(),
            for: sessionID
        )

        _ = try await harness.run()

        #expect(
            (await harness.translator.receivedRequests()).map(\.sourceText)
                == [source, "A new segment."]
        )
        let prior = try #require(
            await harness.store.finishedSessions().first { $0.id == sessionID }
        )
        #expect(prior.entries.map(\.sourceText) == [source])
    }

    private func expectAtomicRecoveryDespiteRecognitionDrift(
        unversionedV1: Bool
    ) async throws {
        let harness = SessionTestHarness(
            recognizedTexts: [
                "Grace truly saves us. Christ remains Lord.",
                "A new segment.",
            ],
            translationMode: .englishToSimplifiedChinese
        )
        let sessionID = UUID()
        await harness.store.begin(priorSession(id: sessionID))
        let segment = recoverySegment()
        await harness.store.seed(completedRootEntry(for: segment))
        if unversionedV1 {
            _ = try await harness.recoveryStore.stageLegacySentenceEntries(
                segment,
                for: sessionID
            )
        } else {
            _ = try await harness.recoveryStore.stage(segment, for: sessionID)
        }

        _ = try await harness.run()

        #expect(
            (await harness.translator.receivedRequests()).map(\.sourceText)
                == ["A new segment."]
        )
        let prior = try #require(
            await harness.store.finishedSessions().first { $0.id == sessionID }
        )
        #expect(prior.entries.map(\.sourceText) == ["Grace saves us. Christ is Lord."])
    }

    private func completedRootEntry(for segment: SpeechSegment) -> TranscriptEntry {
        TranscriptEntry(
            id: segment.id,
            sequence: 1,
            sourceSegmentSequence: 7,
            sourceText: "Grace saves us. Christ is Lord.",
            targetText: "恩典拯救我们。基督是主。",
            startedMilliseconds: 0,
            endedMilliseconds: 20,
            translationMilliseconds: 10
        )
    }

    private func priorSession(id: UUID) -> TranscriptSession {
        TranscriptSession(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1),
            endedAt: nil,
            entries: [],
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
    }

    private func recoverySegment() -> SpeechSegment {
        SpeechSegment(
            sequenceNumber: 7,
            samples: SessionTestHarness.audioFrame.samples,
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .endOfStream
        )
    }
}
