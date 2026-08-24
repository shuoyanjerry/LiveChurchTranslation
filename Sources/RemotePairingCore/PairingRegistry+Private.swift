import Foundation
import RemotePairingAPI
import RemoteSharingAPI

extension PairingRegistry {
    var activeGrantCount: Int {
        grants.values.lazy.filter { !$0.revoked }.count
    }

    func validatedInvitation(
        _ redemption: PairingRedemption,
        now: Date
    ) throws -> InvitationState {
        guard let invitation = invitations[redemption.invitationID] else {
            throw PairingError.invalidInvitation
        }
        if let expiresAt = invitation.expiresAt, expiresAt <= now {
            invitations.removeValue(forKey: redemption.invitationID)
            throw PairingError.invitationExpired
        }
        guard invitation.role == .viewer || !invitation.used else {
            throw PairingError.invitationAlreadyUsed
        }
        guard
            CredentialHasher.matches(
                redemption.fragmentCredential,
                hash: invitation.credentialHash
            )
        else {
            throw PairingError.invalidInvitation
        }
        return invitation
    }

    func replacementViewerGrants(
        invitation: InvitationState,
        clientBinding: RemotePairingClientBinding
    ) -> [RemoteGrantID: GrantState] {
        guard invitation.role == .viewer else { return [:] }
        return grants.filter {
            $0.value.peer.role == .viewer && $0.value.clientBinding == clientBinding
        }
    }

    func removeReplacedGrants(_ replaced: [RemoteGrantID: GrantState], now: Date) {
        for (grantID, state) in replaced {
            grants.removeValue(forKey: grantID)
            appendAudit(audit(state.peer, action: .revoked, now: now))
        }
    }

    func makeGrant(
        _ metadata: RemotePeerMetadata,
        invitation: InvitationState,
        clientBinding: RemotePairingClientBinding,
        bearerCredential: String,
        now: Date
    ) -> PairingGrant {
        let grantID = RemoteGrantID()
        let peer = RemotePeer(
            id: RemotePeerID(),
            grantID: grantID,
            metadata: sanitized(metadata),
            role: invitation.role,
            pairedAt: now,
            expiresAt: invitation.role == .viewer
                ? nil
                : now.addingTimeInterval(configuration.grantTTL)
        )
        grants[grantID] = GrantState(
            peer: peer,
            clientBinding: clientBinding,
            credentialHash: CredentialHasher.hash(
                bearerCredential,
                clientBinding: clientBinding
            ),
            revoked: false
        )
        appendAudit(audit(peer, action: .paired, now: now))
        return PairingGrant(peer: peer, bearerCredential: bearerCredential)
    }

    func purgeExpired(now: Date) {
        grants = grants.filter { !$0.value.revoked }
        invitations = invitations.filter { _, invitation in
            guard !invitation.used else { return false }
            guard let expiresAt = invitation.expiresAt else {
                return invitation.role == .viewer
            }
            return expiresAt > now
        }
        let expired = grants.values.filter { state in
            guard !state.revoked, let expiresAt = state.peer.expiresAt else { return false }
            return expiresAt <= now
        }
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
        let peers = grants.values.filter { state in
            guard !state.revoked else { return false }
            return state.peer.expiresAt.map { $0 > now } ?? true
        }.map(\.peer)
            .sorted { $0.pairedAt < $1.pairedAt }
        let pending = invitations.values.filter { invitation in
            guard !invitation.used else { return false }
            guard let expiresAt = invitation.expiresAt else {
                return invitation.role == .viewer
            }
            return expiresAt > now
        }.count
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
