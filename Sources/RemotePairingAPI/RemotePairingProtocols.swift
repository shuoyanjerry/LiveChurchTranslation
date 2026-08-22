import Foundation
import RemoteSharingAPI

public protocol RemotePairingServing: Sendable {
    func redeem(_ redemption: PairingRedemption, now: Date) async throws -> PairingGrant
    func authorize(
        bearerCredential: String,
        requiresMutation: Bool,
        now: Date
    ) async throws -> RemotePairingAuthorization
}

public protocol RemotePairingManaging: Sendable {
    func issueMacApprovedInvitation(role: RemoteRole, now: Date) async throws -> PairingInvitation
    func activePeers(now: Date) async -> [RemotePeer]
    func snapshot(now: Date) async -> RemotePairingSnapshot
    func revoke(grantID: RemoteGrantID, now: Date) async
    func revokeAll(now: Date) async
    func auditLog() async -> [PairingAuditRecord]
    func events() async -> AsyncStream<RemotePairingEvent>
}
