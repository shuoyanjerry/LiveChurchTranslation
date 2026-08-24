import Foundation
import RemotePairingAPI
import RemotePairingCore
import RemoteSharingAPI
import Testing

func pairForTest(
    role: RemoteRole,
    registry: PairingRegistry,
    clientBinding: RemotePairingClientBinding,
    now: Date
) async throws -> PairingGrant {
    let invitation = try await registry.issueMacApprovedInvitation(role: role, now: now)
    return try await redeemForTest(
        invitation,
        registry: registry,
        clientBinding: clientBinding,
        now: now.addingTimeInterval(1)
    )
}

func redeemForTest(
    _ invitation: PairingInvitation,
    registry: PairingRegistry,
    clientBinding: RemotePairingClientBinding,
    now: Date
) async throws -> PairingGrant {
    try await registry.redeem(
        pairingTestRedemption(invitation),
        clientBinding: clientBinding,
        now: now
    )
}

func pairingTestRedemption(_ invitation: PairingInvitation) -> PairingRedemption {
    PairingRedemption(
        invitationID: invitation.id,
        fragmentCredential: invitation.fragmentCredential,
        peerMetadata: .init(displayName: "Device", userAgentSummary: "Safari")
    )
}

func pairingTestBinding(
    _ value: String = "192.168.10.20"
) throws -> RemotePairingClientBinding {
    try #require(RemotePairingClientBinding(rawValue: value))
}
