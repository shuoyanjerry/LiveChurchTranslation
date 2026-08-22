import Foundation
import RemotePairingAPI
import RemoteSharingAPI

extension PairingRegistry {
    public func revoke(grantID: RemoteGrantID, now: Date = Date()) {
        guard var state = grants[grantID], !state.revoked else { return }
        state.revoked = true
        grants[grantID] = state
        appendAudit(audit(state.peer, action: .revoked, now: now))
        emitSnapshot(now: now)
    }

    public func revokeAll(now: Date = Date()) {
        invitations.removeAll(keepingCapacity: false)
        grants.removeAll(keepingCapacity: false)
        appendAudit(.init(timestamp: now, action: .allRevoked))
        emitSnapshot(now: now)
    }

    public func auditLog() -> [PairingAuditRecord] { auditRecords }

    public func activePeers(now: Date = Date()) -> [RemotePeer] {
        purgeExpired(now: now)
        return grants.values.filter { !$0.revoked }.map(\.peer).sorted {
            $0.pairedAt < $1.pairedAt
        }
    }

    public func snapshot(now: Date = Date()) -> RemotePairingSnapshot {
        purgeExpired(now: now)
        return makeSnapshot(now: now)
    }

    public func events() -> AsyncStream<RemotePairingEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            eventContinuations[id] = continuation
            continuation.yield(.snapshotChanged(makeSnapshot(now: Date())))
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeEventContinuation(id) }
            }
        }
    }
}
