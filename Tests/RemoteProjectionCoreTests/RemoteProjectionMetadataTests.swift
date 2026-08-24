import Foundation
import RemoteProjectionCore
import RemoteSharingAPI
import Testing

@Suite("Remote projection metadata")
struct RemoteProjectionMetadataTests {
    @Test("Projected entries retain their session-relative timestamp")
    func sessionRelativeTimestamp() async throws {
        let store = RemoteProjectionStore()
        await store.beginSession(id: UUID())
        let input = RemoteProjectionEntryInput(
            id: UUID(),
            sequence: 1,
            sourceText: "恩典",
            targetText: "Grace",
            createdAt: .now,
            startedMilliseconds: 135_999
        )

        let projected = try await store.upsert(input)
        let wireData = try JSONEncoder().encode(projected)
        let decoded = try JSONDecoder().decode(RemoteTranscriptEntry.self, from: wireData)

        #expect(projected.startedMilliseconds == 135_999)
        #expect(decoded.startedMilliseconds == 135_999)
    }

    @Test("The snapshot carries the session language pair before the first entry")
    func languagePairPrecedesEntries() async {
        let store = RemoteProjectionStore()
        await store.beginSession(
            id: UUID(),
            message: "Preparing",
            sourceLanguage: "zh-Hans",
            targetLanguage: "en"
        )

        await expectLanguagePair(in: store)
    }

    @Test("Language-aware state updates survive the wire codec")
    func languagePairWireRoundTrip() throws {
        let envelope = RemoteProjectionEnvelope(
            payload: .stateChanged(
                sessionID: UUID(),
                phase: .preparing,
                message: "Preparing",
                sourceLanguage: "zh-Hans",
                targetLanguage: "en",
                revision: 42
            )
        )

        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(RemoteProjectionEnvelope.self, from: encoded)

        #expect(decoded == envelope)
    }

    private func expectLanguagePair(in store: RemoteProjectionStore) async {
        let snapshot = await store.snapshot()
        #expect(snapshot.entries.isEmpty)
        #expect(snapshot.sourceLanguage == "zh-Hans")
        #expect(snapshot.targetLanguage == "en")

        let peerID = RemotePeerID()
        _ = await store.connect(peerID: peerID)
        await store.updateState(
            phase: .listening,
            message: "Live",
            sourceLanguage: "zh-Hans",
            targetLanguage: "en"
        )
        let envelopes = await store.drain(peerID: peerID, limit: 1)
        guard let payload = envelopes.first?.payload,
            case .stateChanged(_, _, _, let sourceLanguage, let targetLanguage, _) = payload
        else {
            Issue.record("Expected a language-aware state update")
            return
        }
        #expect(sourceLanguage == "zh-Hans")
        #expect(targetLanguage == "en")
    }
}
