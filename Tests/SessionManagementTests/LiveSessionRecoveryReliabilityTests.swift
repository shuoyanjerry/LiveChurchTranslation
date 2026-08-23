import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

@Suite struct LiveSessionRecoveryReliabilityTests {
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
        _ = try await harness.recoveryStore.stage(segment, for: priorSessionID)

        _ = try await harness.run()

        #expect((await harness.translator.receivedRequests()).count == 2)
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect((await harness.recoveryStore.completedIDs()).count == 2)
        #expect((await harness.store.finishedSessions()).contains { $0.id == priorSessionID })
    }

    @Test func recoveryNeverUsesFutureTranscriptAsContext() async throws {
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
        await harness.store.seed(
            TranscriptEntry(
                sequence: 10,
                sourceText: "未来的姐妹会分享。",
                targetText: "A sister will share later.",
                startedMilliseconds: 1_000,
                endedMilliseconds: 2_000,
                translationMilliseconds: 10
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
        _ = try await harness.recoveryStore.stage(segment, for: priorSessionID)

        _ = try await harness.run()

        let recoveryRequest = try #require(await harness.translator.receivedRequests().first)
        #expect(recoveryRequest.context.isEmpty)
    }
}

extension LiveSessionRecoveryReliabilityTests {
    @Test func splitSentenceRecoverySkipsAlreadyPersistedDeterministicEntry() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: [
                "Grace saves us. Christ is Lord.",
                "We pray.",
            ],
            translationMode: .englishToSimplifiedChinese
        )
        let fixture = try await stageSplitRecoveryFixture(harness)

        _ = try await harness.run()

        let requests = await harness.translator.receivedRequests()
        #expect(requests.map(\.sourceText) == ["Christ is Lord.", "We pray."])
        #expect(requests[0].context.map(\.sourceText) == ["Grace saves us."])
        let expectedSecondID = SentenceEntryIdentity.make(
            sourceSegmentID: fixture.segment.id,
            ordinal: 1
        )
        let persisted = await harness.store.persistedEntries()
        #expect(persisted.filter { $0.id == fixture.segment.id }.count == 1)
        #expect(persisted.filter { $0.id == expectedSecondID }.count == 1)
        let prior = try #require(
            await harness.store.finishedSessions().first { $0.id == fixture.sessionID }
        )
        #expect(prior.entries.map(\.sourceText) == ["Grace saves us.", "Christ is Lord."])
        #expect(prior.entries.map(\.sequence) == [1, 2])
        #expect(prior.entries.compactMap(\.sourceSegmentSequence) == [7, 7])
    }

    private func stageSplitRecoveryFixture(
        _ harness: SessionTestHarness
    ) async throws -> (sessionID: UUID, segment: SpeechSegment) {
        let sessionID = UUID()
        await harness.store.begin(
            TranscriptSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: [],
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
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
        await harness.store.seed(
            TranscriptEntry(
                id: segment.id,
                sequence: 1,
                sourceSegmentSequence: 7,
                sourceText: "Grace saves us.",
                targetText: "我们因恩典得救。",
                startedMilliseconds: 0,
                endedMilliseconds: 10,
                translationMilliseconds: 10
            )
        )
        _ = try await harness.recoveryStore.stage(segment, for: sessionID)
        return (sessionID, segment)
    }
}
