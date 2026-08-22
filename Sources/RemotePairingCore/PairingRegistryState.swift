import Foundation
import RemotePairingAPI
import RemoteSharingAPI

struct InvitationState: Sendable {
    let role: RemoteRole
    let credentialHash: Data
    let expiresAt: Date
    var used: Bool
}

struct GrantState: Sendable {
    let peer: RemotePeer
    let credentialHash: Data
    var revoked: Bool
}
