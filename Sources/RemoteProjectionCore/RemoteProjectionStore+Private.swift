import RemoteSharingAPI

extension RemoteProjectionStore {
    func makeSnapshot() -> RemoteProjectionSnapshot {
        RemoteProjectionSnapshot(
            sessionID: sessionID,
            revision: revision,
            phase: phase,
            statusMessage: statusMessage,
            entries: entries.values.sorted(by: entryOrder),
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }

    func broadcast(_ envelope: RemoteProjectionEnvelope) {
        for peerID in outboxes.keys {
            outboxes[peerID]?.enqueue(envelope, latestRevision: revision)
        }
    }

    func evictIfNeeded() {
        var ordered = entries.values.sorted { $0.revision < $1.revision }
        var utf8Bytes = ordered.reduce(0) { count, entry in
            count + entry.sourceText.utf8.count + entry.targetText.utf8.count
        }
        while exceedsRetentionLimits(utf8Bytes: utf8Bytes) {
            guard !ordered.isEmpty else { return }
            let oldest = ordered.removeFirst()
            entries.removeValue(forKey: oldest.id)
            utf8Bytes -= oldest.sourceText.utf8.count + oldest.targetText.utf8.count
        }
    }

    private func exceedsRetentionLimits(utf8Bytes: Int) -> Bool {
        entries.count > configuration.maximumSnapshotEntries
            || utf8Bytes > configuration.maximumSnapshotUTF8Bytes
    }

    func entryOrder(_ left: RemoteTranscriptEntry, _ right: RemoteTranscriptEntry) -> Bool {
        if left.sequence != right.sequence { return left.sequence < right.sequence }
        if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
        return left.id.uuidString < right.id.uuidString
    }
}
