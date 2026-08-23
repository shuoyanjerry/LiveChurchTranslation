import Foundation
import RemoteSharingAPI

public actor RemoteProjectionStore: RemoteProjectionProviding, RemoteProjectionUpdating {
    let configuration: ProjectionConfiguration
    var sessionID: UUID?
    var phase = RemoteSessionPhase.idle
    var statusMessage = "Ready"
    var revision: UInt64 = 0
    var entries: [UUID: RemoteTranscriptEntry] = [:]
    var outboxes: [RemotePeerID: PeerOutbox] = [:]

    public init(configuration: ProjectionConfiguration = ProjectionConfiguration()) {
        self.configuration = configuration
    }

    public func connect(peerID: RemotePeerID) -> RemoteProjectionConnection {
        let connection = RemoteProjectionConnection(peerID: peerID, snapshot: makeSnapshot())
        outboxes[peerID] = PeerOutbox(capacity: configuration.peerQueueCapacity)
        return connection
    }

    public func disconnect(peerID: RemotePeerID) {
        outboxes.removeValue(forKey: peerID)
    }

    public func drain(peerID: RemotePeerID, limit: Int) -> [RemoteProjectionEnvelope] {
        guard var outbox = outboxes[peerID] else { return [] }
        let drained = outbox.drain(limit: min(max(limit, 0), 256))
        outboxes[peerID] = outbox
        return drained
    }

    public func snapshot() -> RemoteProjectionSnapshot { makeSnapshot() }

    public func beginSession(id: UUID, message: String = "Preparing") {
        sessionID = id
        entries.removeAll(keepingCapacity: true)
        updateState(phase: .preparing, message: message)
    }

    public func updateState(phase newPhase: RemoteSessionPhase, message: String) {
        phase = newPhase
        statusMessage = String(message.prefix(256))
        revision &+= 1
        broadcast(
            .init(
                payload: .stateChanged(
                    sessionID: sessionID,
                    phase: phase,
                    message: statusMessage,
                    revision: revision
                )))
    }

    @discardableResult
    public func upsert(_ input: RemoteProjectionEntryInput) throws -> RemoteTranscriptEntry {
        guard input.sourceText.count <= configuration.maximumTextCharacters,
            input.targetText.count <= configuration.maximumTextCharacters
        else {
            throw ProjectionError.textTooLarge
        }
        revision &+= 1
        let entry = RemoteTranscriptEntry(
            id: input.id,
            sequence: input.sequence,
            revision: revision,
            sourceText: input.sourceText,
            targetText: input.targetText,
            createdAt: input.createdAt,
            sourceLanguage: input.sourceLanguage,
            targetLanguage: input.targetLanguage
        )
        entries[input.id] = entry
        evictIfNeeded()
        guard let sessionID else { return entry }
        broadcast(
            .init(
                payload: .entryUpsert(
                    sessionID: sessionID,
                    entry: entry,
                    revision: revision
                )))
        return entry
    }

    public func heartbeat() {
        broadcast(.init(payload: .heartbeat(revision: revision)))
    }
}
