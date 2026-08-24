import Foundation
import RemoteSharingAPI

public actor RemoteProjectionStore: RemoteProjectionProviding, RemoteProjectionUpdating {
    let configuration: ProjectionConfiguration
    var sessionID: UUID?
    var phase = RemoteSessionPhase.idle
    var statusMessage = "等待 Mac 开始"
    var sourceLanguage: String?
    var targetLanguage: String?
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

    public func beginSession(id: UUID, message: String = "正在准备本地翻译") {
        beginSession(
            id: id,
            message: message,
            sourceLanguage: nil,
            targetLanguage: nil
        )
    }

    public func beginSession(
        id: UUID,
        message: String,
        sourceLanguage: String?,
        targetLanguage: String?
    ) {
        sessionID = id
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        entries.removeAll(keepingCapacity: true)
        updateState(phase: .preparing, message: message)
    }

    public func updateState(phase newPhase: RemoteSessionPhase, message: String) {
        updateState(
            phase: newPhase,
            message: message,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    public func updateState(
        phase newPhase: RemoteSessionPhase,
        message: String,
        sourceLanguage: String?,
        targetLanguage: String?
    ) {
        phase = newPhase
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        statusMessage = String(message.prefix(256))
        revision &+= 1
        broadcast(
            .init(
                payload: .stateChanged(
                    sessionID: sessionID,
                    phase: phase,
                    message: statusMessage,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
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
            startedMilliseconds: input.startedMilliseconds,
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
