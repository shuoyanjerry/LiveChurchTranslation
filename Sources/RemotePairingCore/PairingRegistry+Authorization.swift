import Foundation
import RemotePairingAPI
import RemoteSharingAPI

extension PairingRegistry {
    public func authorize(
        bearerCredential: String,
        clientBinding: RemotePairingClientBinding,
        requiresMutation: Bool,
        now: Date = Date()
    ) throws -> RemotePairingAuthorization {
        guard
            let match = grants.first(where: {
                $0.value.clientBinding == clientBinding
                    && CredentialHasher.matches(
                        bearerCredential,
                        clientBinding: clientBinding,
                        hash: $0.value.credentialHash
                    )
            })
        else {
            recordDenial(now: now)
            throw PairingError.invalidGrant
        }
        let state = match.value
        guard !state.revoked else { throw PairingError.grantRevoked }
        if let expiresAt = state.peer.expiresAt, expiresAt <= now {
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
