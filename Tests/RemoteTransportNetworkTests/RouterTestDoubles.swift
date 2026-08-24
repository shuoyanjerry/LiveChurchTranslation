import Foundation
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI
import RemoteWebAssetsAPI

actor EnabledSharing: RemoteSharingControlling {
    private var enabled = true
    func isEnabled() -> Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}

struct ViewerPairing: RemotePairingServing {
    func redeem(
        _ redemption: PairingRedemption,
        clientBinding: RemotePairingClientBinding,
        now: Date
    ) async throws -> PairingGrant {
        throw PairingError.invalidInvitation
    }

    func authorize(
        bearerCredential: String,
        clientBinding: RemotePairingClientBinding,
        requiresMutation: Bool,
        now: Date
    ) async throws -> RemotePairingAuthorization {
        guard !requiresMutation else { throw PairingError.viewerIsReadOnly }
        return .init(peerID: .init(), grantID: .init(), role: .viewer)
    }
}

actor ProjectionFake: RemoteProjectionProviding {
    func connect(peerID: RemotePeerID) -> RemoteProjectionConnection {
        .init(peerID: peerID, snapshot: makeSnapshot())
    }

    func disconnect(peerID: RemotePeerID) {}
    func drain(peerID: RemotePeerID, limit: Int) -> [RemoteProjectionEnvelope] { [] }
    func snapshot() -> RemoteProjectionSnapshot { makeSnapshot() }

    private func makeSnapshot() -> RemoteProjectionSnapshot {
        .init(sessionID: nil, revision: 7, phase: .idle, statusMessage: "Ready", entries: [])
    }
}

actor CommandSpy: RemoteSessionCommandHandling {
    private var callCount = 0

    func handle(
        _ request: RemoteControlRequest,
        authorization: RemoteControlAuthorization
    ) -> RemoteControlResult {
        callCount += 1
        return .init(requestID: request.requestID, accepted: true, authoritativeRevision: 8)
    }

    func calls() -> Int { callCount }
}

struct EmptyAssets: RemoteWebAssetProviding {
    func asset(for requestPath: String) -> RemoteWebAsset? { nil }
}
