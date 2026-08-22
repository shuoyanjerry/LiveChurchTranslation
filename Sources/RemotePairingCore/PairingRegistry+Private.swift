import Foundation
import RemotePairingAPI
import RemoteSharingAPI

extension PairingRegistry {
    var activeGrantCount: Int {
        grants.values.lazy.filter { !$0.revoked }.count
    }

    func makeGrant(
        _ metadata: RemotePeerMetadata,
        invitation: InvitationState,
        now: Date
    ) throws -> PairingGrant {
        let credential = try tokenGenerator.token(byteCount: 32)
        let grantID = RemoteGrantID()
        let peer = RemotePeer(
            id: RemotePeerID(),
            grantID: grantID,
            metadata: sanitized(metadata),
            role: invitation.role,
            pairedAt: now,
            expiresAt: now.addingTimeInterval(configuration.grantTTL)
        )
        grants[grantID] = GrantState(
            peer: peer,
            credentialHash: CredentialHasher.hash(credential),
            revoked: false
        )
        appendAudit(audit(peer, action: .paired, now: now))
        return PairingGrant(peer: peer, bearerCredential: credential)
    }

    func purgeExpired(now: Date) {
        invitations = invitations.filter { $0.value.expiresAt > now && !$0.value.used }
        let expired = grants.values.filter { !$0.revoked && $0.peer.expiresAt <= now }
        for state in expired {
            grants.removeValue(forKey: state.peer.grantID)
            appendAudit(audit(state.peer, action: .expired, now: now))
        }
    }

    func sanitized(_ metadata: RemotePeerMetadata) -> RemotePeerMetadata {
        RemotePeerMetadata(
            displayName: String(metadata.displayName.prefix(80)),
            userAgentSummary: String(metadata.userAgentSummary.prefix(160))
        )
    }

    func audit(
        _ peer: RemotePeer,
        action: PairingAuditRecord.Action,
        now: Date
    ) -> PairingAuditRecord {
        PairingAuditRecord(
            timestamp: now,
            action: action,
            role: peer.role,
            peerID: peer.id,
            grantID: peer.grantID
        )
    }

    func appendAudit(_ record: PairingAuditRecord) {
        auditRecords.append(record)
        if auditRecords.count > configuration.maximumAuditRecords {
            auditRecords.removeFirst(auditRecords.count - configuration.maximumAuditRecords)
        }
        for continuation in eventContinuations.values { continuation.yield(.audit(record)) }
    }

    func recordDenial(now: Date) {
        appendAudit(.init(timestamp: now, action: .authorizationDenied))
    }

    func makeSnapshot(now: Date) -> RemotePairingSnapshot {
        let peers = grants.values.filter { !$0.revoked && $0.peer.expiresAt > now }.map(\.peer)
            .sorted { $0.pairedAt < $1.pairedAt }
        let pending = invitations.values.filter { !$0.used && $0.expiresAt > now }.count
        return RemotePairingSnapshot(activePeers: peers, pendingInvitationCount: pending)
    }

    func emitSnapshot(now: Date) {
        let event = RemotePairingEvent.snapshotChanged(makeSnapshot(now: now))
        for continuation in eventContinuations.values { continuation.yield(event) }
    }

    func removeEventContinuation(_ id: UUID) {
        eventContinuations.removeValue(forKey: id)
    }
}
