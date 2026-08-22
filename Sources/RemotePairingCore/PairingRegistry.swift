import Foundation
import RemotePairingAPI
import RemoteSharingAPI

public actor PairingRegistry: RemotePairingServing, RemotePairingManaging {
    let configuration: PairingConfiguration
    let tokenGenerator: any SecureTokenGenerating
    var invitations: [UUID: InvitationState] = [:]
    var grants: [RemoteGrantID: GrantState] = [:]
    var auditRecords: [PairingAuditRecord] = []
    var eventContinuations: [UUID: AsyncStream<RemotePairingEvent>.Continuation] = [:]

    public init(
        configuration: PairingConfiguration = PairingConfiguration(),
        tokenGenerator: any SecureTokenGenerating = SystemSecureTokenGenerator()
    ) {
        self.configuration = configuration
        self.tokenGenerator = tokenGenerator
    }

    /// Must only be called by the local Mac UI. Selecting `.operator` is the explicit approval act.
    public func issueMacApprovedInvitation(
        role: RemoteRole,
        now: Date = Date()
    ) throws -> PairingInvitation {
        purgeExpired(now: now)
        guard activeGrantCount < configuration.maximumActiveGrants else {
            throw PairingError.capacityReached
        }
        let credential = try tokenGenerator.token(byteCount: 32)
        let id = UUID()
        let expiry = now.addingTimeInterval(configuration.invitationTTL)
        invitations[id] = InvitationState(
            role: role,
            credentialHash: CredentialHasher.hash(credential),
            expiresAt: expiry,
            used: false
        )
        appendAudit(.init(timestamp: now, action: .invitationIssued, role: role))
        emitSnapshot(now: now)
        return PairingInvitation(
            id: id,
            role: role,
            fragmentCredential: credential,
            expiresAt: expiry
        )
    }

    public func redeem(_ redemption: PairingRedemption, now: Date = Date()) throws -> PairingGrant {
        guard var invitation = invitations[redemption.invitationID] else {
            throw PairingError.invalidInvitation
        }
        guard invitation.expiresAt > now else {
            invitations.removeValue(forKey: redemption.invitationID)
            throw PairingError.invitationExpired
        }
        guard !invitation.used else { throw PairingError.invitationAlreadyUsed }
        guard
            CredentialHasher.matches(
                redemption.fragmentCredential,
                hash: invitation.credentialHash
            )
        else {
            throw PairingError.invalidInvitation
        }
        invitation.used = true
        invitations[redemption.invitationID] = invitation
        let grant = try makeGrant(redemption.peerMetadata, invitation: invitation, now: now)
        emitSnapshot(now: now)
        return grant
    }

    public func authorize(
        bearerCredential: String,
        requiresMutation: Bool,
        now: Date = Date()
    ) throws -> RemotePairingAuthorization {
        guard
            let match = grants.first(where: {
                CredentialHasher.matches(bearerCredential, hash: $0.value.credentialHash)
            })
        else {
            recordDenial(now: now)
            throw PairingError.invalidGrant
        }
        let state = match.value
        guard !state.revoked else { throw PairingError.grantRevoked }
        guard state.peer.expiresAt > now else {
            grants.removeValue(forKey: match.key)
            appendAudit(audit(state.peer, action: .expired, now: now))
            emitSnapshot(now: now)
            throw PairingError.grantExpired
        }
        let authorization = RemotePairingAuthorization(
            peerID: state.peer.id,
            grantID: state.peer.grantID,
            role: state.peer.role
        )
        guard !requiresMutation || authorization.role == .operator else {
            appendAudit(audit(state.peer, action: .authorizationDenied, now: now))
            throw PairingError.viewerIsReadOnly
        }
        return authorization
    }

}
