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
        let expiry: Date? =
            role == .viewer
            ? nil
            : now.addingTimeInterval(configuration.invitationTTL)
        if role == .viewer {
            invitations = invitations.filter { $0.value.role != .viewer }
        }
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

    public func redeem(
        _ redemption: PairingRedemption,
        clientBinding: RemotePairingClientBinding,
        now: Date = Date()
    ) throws -> PairingGrant {
        var invitation = try validatedInvitation(redemption, now: now)
        let isReusableViewerInvitation = invitation.role == .viewer
        purgeExpired(now: now)
        let replacedViewerGrants = replacementViewerGrants(
            invitation: invitation,
            clientBinding: clientBinding
        )
        guard
            activeGrantCount - replacedViewerGrants.count
                < configuration.maximumActiveGrants
        else {
            throw PairingError.capacityReached
        }
        let bearerCredential = try tokenGenerator.token(byteCount: 32)
        removeReplacedGrants(replacedViewerGrants, now: now)
        let grant = makeGrant(
            redemption.peerMetadata,
            invitation: invitation,
            clientBinding: clientBinding,
            bearerCredential: bearerCredential,
            now: now
        )
        if !isReusableViewerInvitation {
            invitation.used = true
            invitations[redemption.invitationID] = invitation
        }
        emitSnapshot(now: now)
        return grant
    }

}
