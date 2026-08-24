import Foundation
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI

actor ListenerPairingFake: RemotePairingServing, RemotePairingManaging {
    let credential = String(repeating: "L", count: 43)
    let grantID = RemoteGrantID()
    private let peer: RemotePeer
    private let maximumAuthorizationCalls: Int?
    private var authorizationCallCount = 0
    private var revoked = false

    init(maximumAuthorizationCalls: Int? = nil) {
        self.maximumAuthorizationCalls = maximumAuthorizationCalls
        peer = RemotePeer(
            id: .init(),
            grantID: grantID,
            metadata: .init(displayName: "Test Safari", userAgentSummary: "Test"),
            role: .viewer,
            pairedAt: Date(timeIntervalSince1970: 1),
            expiresAt: nil
        )
    }

    func redeem(
        _ redemption: PairingRedemption,
        clientBinding: RemotePairingClientBinding,
        now: Date
    ) -> PairingGrant {
        PairingGrant(peer: peer, bearerCredential: credential)
    }

    func authorize(
        bearerCredential: String,
        clientBinding: RemotePairingClientBinding,
        requiresMutation: Bool,
        now: Date
    ) throws -> RemotePairingAuthorization {
        authorizationCallCount += 1
        guard bearerCredential == credential else { throw PairingError.invalidGrant }
        guard !revoked else { throw PairingError.grantRevoked }
        if let maximumAuthorizationCalls {
            guard authorizationCallCount <= maximumAuthorizationCalls else {
                throw PairingError.grantRevoked
            }
        }
        guard !requiresMutation else { throw PairingError.viewerIsReadOnly }
        return .init(peerID: peer.id, grantID: peer.grantID, role: peer.role)
    }

    func issueMacApprovedInvitation(role: RemoteRole, now: Date) throws -> PairingInvitation {
        .init(
            id: UUID(),
            role: role,
            fragmentCredential: credential,
            expiresAt: role == .viewer ? nil : now.addingTimeInterval(60)
        )
    }

    func activePeers(now: Date) -> [RemotePeer] { revoked ? [] : [peer] }
    func snapshot(now: Date) -> RemotePairingSnapshot {
        .init(activePeers: revoked ? [] : [peer], pendingInvitationCount: 0)
    }
    func revokeInvitation(id: UUID, now: Date) {}
    func revoke(grantID: RemoteGrantID, now: Date) {
        if grantID == peer.grantID { revoked = true }
    }
    func revokeAll(now: Date) { revoked = true }
    func auditLog() -> [PairingAuditRecord] { [] }
    func events() -> AsyncStream<RemotePairingEvent> { AsyncStream { $0.finish() } }
    func isRevoked() -> Bool { revoked }
}

actor ListenerCommandFake: RemoteSessionCommandHandling {
    func handle(
        _ request: RemoteControlRequest,
        authorization: RemoteControlAuthorization
    ) -> RemoteControlResult {
        .init(requestID: request.requestID, accepted: false, authoritativeRevision: 0)
    }
}
