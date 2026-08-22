import Foundation
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI

actor ListenerPairingFake: RemotePairingServing, RemotePairingManaging {
    let credential = String(repeating: "L", count: 43)
    private let peer = RemotePeer(
        id: .init(),
        grantID: .init(),
        metadata: .init(displayName: "Test Safari", userAgentSummary: "Test"),
        role: .viewer,
        pairedAt: Date(timeIntervalSince1970: 1),
        expiresAt: Date.distantFuture
    )

    func redeem(_ redemption: PairingRedemption, now: Date) -> PairingGrant {
        PairingGrant(peer: peer, bearerCredential: credential)
    }

    func authorize(
        bearerCredential: String,
        requiresMutation: Bool,
        now: Date
    ) throws -> RemotePairingAuthorization {
        guard bearerCredential == credential else { throw PairingError.invalidGrant }
        guard !requiresMutation else { throw PairingError.viewerIsReadOnly }
        return .init(peerID: peer.id, grantID: peer.grantID, role: peer.role)
    }

    func issueMacApprovedInvitation(role: RemoteRole, now: Date) throws -> PairingInvitation {
        .init(id: UUID(), role: role, fragmentCredential: credential, expiresAt: now.addingTimeInterval(60))
    }

    func activePeers(now: Date) -> [RemotePeer] { [peer] }
    func snapshot(now: Date) -> RemotePairingSnapshot {
        .init(activePeers: [peer], pendingInvitationCount: 0)
    }
    func revoke(grantID: RemoteGrantID, now: Date) {}
    func revokeAll(now: Date) {}
    func auditLog() -> [PairingAuditRecord] { [] }
    func events() -> AsyncStream<RemotePairingEvent> { AsyncStream { $0.finish() } }
}

actor ListenerCommandFake: RemoteSessionCommandHandling {
    func handle(
        _ request: RemoteControlRequest,
        authorization: RemoteControlAuthorization
    ) -> RemoteControlResult {
        .init(requestID: request.requestID, accepted: false, authoritativeRevision: 0)
    }
}
