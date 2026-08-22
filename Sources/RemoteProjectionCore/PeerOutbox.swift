import RemoteSharingAPI

struct PeerOutbox: Sendable {
    private(set) var pending: [RemoteProjectionEnvelope] = []
    let capacity: Int

    mutating func enqueue(_ envelope: RemoteProjectionEnvelope, latestRevision: UInt64) {
        if isWaitingForResync {
            pending = [.init(payload: .resyncRequired(latestRevision: latestRevision))]
            return
        }
        guard pending.count < capacity else {
            pending = [.init(payload: .resyncRequired(latestRevision: latestRevision))]
            return
        }
        pending.append(envelope)
    }

    mutating func drain(limit: Int) -> [RemoteProjectionEnvelope] {
        let count = min(max(limit, 0), pending.count)
        guard count > 0 else { return [] }
        let drained = Array(pending.prefix(count))
        pending.removeFirst(count)
        return drained
    }

    private var isWaitingForResync: Bool {
        guard pending.count == 1 else { return false }
        if case .resyncRequired = pending[0].payload { return true }
        return false
    }
}
