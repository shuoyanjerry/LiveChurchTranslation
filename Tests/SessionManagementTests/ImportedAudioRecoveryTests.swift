import Foundation
@testable import SessionManagement
import Testing
import TranscriptAPI
import VADAPI

@Suite struct ImportedAudioRecoveryTests {
    @Test func crashRecoveryTranscribesWithoutCallingTranslator() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["恢复的第一段。", "恢复的第二段。"],
            translationFails: true
        )
        let sessionID = UUID()
        await beginImportedSession(harness, id: sessionID)
        try await stage(harness, sessionID: sessionID, count: 2)

        let issues = await makeReplayer(harness).replay()

        #expect(issues.isEmpty)
        #expect((await harness.asr.receivedRequests()).count == 2)
        #expect((await harness.translator.receivedRequests()).isEmpty)
        let entries = await harness.store.appendedEntries()
        #expect(entries.map(\.sourceText) == ["恢复的第一段。", "恢复的第二段。"])
        #expect(entries.allSatisfy(Self.isSourceOnly))
        #expect((await harness.recoveryStore.pendingRecords()).isEmpty)
        #expect(Set((await harness.recoveryStore.completedIDs()).map(\.sequenceNumber)) == [1, 2])
    }

    @Test func importedSessionDoesNotAttemptPendingLiveTranslationRecovery() async throws {
        let harness = SessionTestHarness(
            translationFails: true,
            sessionKind: .importedAudio
        )
        let priorSessionID = UUID()
        await beginLiveSession(harness, id: priorSessionID)
        try await stage(harness, sessionID: priorSessionID, count: 1)

        _ = try await harness.run()

        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect(await harness.translator.loadCount() == 0)
        #expect(await harness.translator.runtimeCheckCount() == 0)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.recoveryStore.pendingRecords()).map(\.id.sessionID) == [priorSessionID])
        #expect(await harness.coordinator.currentSnapshot().finalizationOutcome == .saved)
    }

    @Test func recoveryUsesEnglishSourceLocaleAndIgnoresHistoricalTarget() async throws {
        let harness = SessionTestHarness(
            recognizedTexts: ["Recovered source only."],
            translationFails: true
        )
        let sessionID = UUID()
        await beginImportedSession(
            harness,
            id: sessionID,
            sourceLanguage: "en_CA",
            targetLanguage: "unsupported-target"
        )
        try await stage(harness, sessionID: sessionID, count: 1)

        let issues = await makeReplayer(harness).replay()

        #expect(issues.isEmpty)
        #expect((await harness.asr.receivedRequests()).map(\.languageCode) == ["en"])
        #expect((await harness.translator.receivedRequests()).isEmpty)
        let entries = await harness.store.appendedEntries()
        #expect(entries.count == 1)
        let entry = try #require(entries.first)
        #expect(entry.sourceText == "Recovered source only.")
        #expect(Self.isSourceOnly(entry))
    }

    private func makeReplayer(
        _ harness: SessionTestHarness
    ) async -> UtteranceRecoveryReplayer {
        let dependencies = await harness.coordinator.dependencies
        return UtteranceRecoveryReplayer(
            dependencies: dependencies,
            processor: UtteranceProcessor(dependencies: dependencies),
            excludedSessionID: nil
        )
    }

    private func beginImportedSession(
        _ harness: SessionTestHarness,
        id: UUID,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "unsupported-target"
    ) async {
        await harness.store.begin(
            TranscriptSession(
                id: id,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: [],
                kind: .importedAudio,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        )
    }

    private func beginLiveSession(_ harness: SessionTestHarness, id: UUID) async {
        await harness.store.begin(
            TranscriptSession(
                id: id,
                startedAt: Date(timeIntervalSince1970: 1),
                endedAt: nil,
                entries: []
            )
        )
    }

    private func stage(
        _ harness: SessionTestHarness,
        sessionID: UUID,
        count: Int
    ) async throws {
        for sequence in 1...count {
            _ = try await harness.recoveryStore.stage(
                SpeechSegment(
                    sequenceNumber: UInt64(sequence),
                    samples: SessionTestHarness.audioFrame.samples,
                    sampleRate: 16_000,
                    startedAt: .milliseconds(Int64((sequence - 1) * 20)),
                    endedAt: .milliseconds(Int64(sequence * 20)),
                    endReason: .trailingSilence
                ),
                for: sessionID
            )
        }
    }

    private static func isSourceOnly(_ entry: TranscriptEntry) -> Bool {
        entry.targetText.isEmpty
            && entry.translationReview == nil
            && entry.translationMilliseconds == 0
    }
}
