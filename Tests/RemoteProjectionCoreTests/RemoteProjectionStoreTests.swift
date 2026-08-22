import Foundation
import RemoteProjectionCore
import RemoteSharingAPI
import Testing

@Suite("Remote projection store")
struct RemoteProjectionStoreTests {
    @Test("Late lower sequence upserts remain in authoritative order")
    func lateLowerSequence() async throws {
        let store = RemoteProjectionStore()
        await store.beginSession(id: UUID())
        _ = try await store.upsert(entry(sequence: 12, text: "second"))
        _ = try await store.upsert(entry(sequence: 4, text: "late first"))
        let snapshot = await store.snapshot()
        #expect(snapshot.entries.map(\.sequence) == [4, 12])
    }

    @Test("Connect creates an atomic snapshot-to-live barrier")
    func snapshotLiveBarrier() async throws {
        let store = RemoteProjectionStore()
        await store.beginSession(id: UUID())
        _ = try await store.upsert(entry(sequence: 1, text: "snapshot"))
        let peerID = RemotePeerID()
        let connection = await store.connect(peerID: peerID)
        _ = try await store.upsert(entry(sequence: 2, text: "live"))
        let messages = await store.drain(peerID: peerID, limit: 10)
        #expect(messages.count == 1)
        guard case .entryUpsert(_, let entry, let revision) = messages[0].payload else {
            Issue.record("Expected a live upsert")
            return
        }
        #expect(entry.targetText == "live")
        #expect(revision > connection.snapshot.revision)
    }

    @Test("A slow peer is reduced to one resync signal")
    func slowPeerBackpressure() async throws {
        let store = RemoteProjectionStore(configuration: .init(peerQueueCapacity: 2))
        await store.beginSession(id: UUID())
        let peerID = RemotePeerID()
        _ = await store.connect(peerID: peerID)
        for sequence in 1...5 {
            _ = try await store.upsert(entry(sequence: sequence, text: "entry \(sequence)"))
        }
        let messages = await store.drain(peerID: peerID, limit: 10)
        #expect(messages.count == 1)
        guard case .resyncRequired = messages[0].payload else {
            Issue.record("Expected resyncRequired after queue overflow")
            return
        }
    }

    @Test("The authoritative snapshot is bounded")
    func boundedSnapshot() async throws {
        let store = RemoteProjectionStore(configuration: .init(maximumSnapshotEntries: 2))
        await store.beginSession(id: UUID())
        for sequence in 1...3 {
            _ = try await store.upsert(entry(sequence: sequence, text: "entry \(sequence)"))
        }
        #expect(await store.snapshot().entries.map(\.sequence) == [2, 3])
    }

    private func entry(sequence: Int, text: String) -> RemoteProjectionEntryInput {
        RemoteProjectionEntryInput(
            id: UUID(),
            sequence: sequence,
            sourceText: "中文 \(text)",
            targetText: text,
            createdAt: Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }
}
