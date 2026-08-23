import Foundation
import RemotePairingAPI
import RemoteSharingAPI
import RemoteTransportNetwork
import Testing

@Suite("WebSocket continuous authorization")
struct RemoteSocketSessionAuthorizationTests {
    @Test("Revocation blocks the next drain and disconnects exactly once")
    func revokedGrantFailsClosed() async throws {
        let fixture = makeFixture()
        _ = try await fixture.session.outgoing()
        #expect(await fixture.projection.drainCalls() == 1)

        await fixture.pairing.setMode(.revoked)
        await #expect(throws: RemoteTransportError.unauthorized) {
            try await fixture.session.outgoing()
        }
        await fixture.session.close()
        await fixture.session.close()

        #expect(await fixture.projection.drainCalls() == 1)
        #expect(await fixture.projection.disconnectCalls() == 1)
    }

    @Test("Expiry blocks an inbound frame before it is handled")
    func expiredGrantFailsClosed() async {
        let fixture = makeFixture()
        await fixture.pairing.setMode(.expired)

        await #expect(throws: RemoteTransportError.unauthorized) {
            try await fixture.session.receive(.init(opcode: .ping, payload: Data("x".utf8)))
        }

        #expect(await fixture.projection.disconnectCalls() == 1)
        #expect(await fixture.pairing.authorizationCalls() == 1)
    }

    @Test(arguments: [true, false])
    func changedGrantIdentityFailsClosed(wrongPeer: Bool) async {
        let fixture = makeFixture()
        await fixture.pairing.setMode(wrongPeer ? .wrongPeer : .wrongGrant)

        await #expect(throws: RemoteTransportError.unauthorized) {
            try await fixture.session.outgoing()
        }

        #expect(await fixture.projection.drainCalls() == 0)
        #expect(await fixture.projection.disconnectCalls() == 1)
    }

    private func makeFixture() -> SessionAuthorizationFixture {
        let peerID = RemotePeerID()
        let grantID = RemoteGrantID()
        let credential = String(repeating: "S", count: 43)
        let pairing = SessionPairingFake(peerID: peerID, grantID: grantID, credential: credential)
        let projection = SessionProjectionSpy()
        let session = RemoteSocketSession(
            peerID: peerID,
            grantID: grantID,
            bearerCredential: credential,
            pairing: pairing,
            projection: projection
        )
        return .init(pairing: pairing, projection: projection, session: session)
    }
}

private struct SessionAuthorizationFixture {
    let pairing: SessionPairingFake
    let projection: SessionProjectionSpy
    let session: RemoteSocketSession
}

private actor SessionPairingFake: RemotePairingServing {
    enum Mode: Sendable {
        case authorized
        case revoked
        case expired
        case wrongPeer
        case wrongGrant
    }

    private let peerID: RemotePeerID
    private let grantID: RemoteGrantID
    private let credential: String
    private var mode = Mode.authorized
    private var callCount = 0

    init(peerID: RemotePeerID, grantID: RemoteGrantID, credential: String) {
        self.peerID = peerID
        self.grantID = grantID
        self.credential = credential
    }

    func redeem(_ redemption: PairingRedemption, now: Date) throws -> PairingGrant {
        throw PairingError.invalidInvitation
    }

    func authorize(
        bearerCredential: String,
        requiresMutation: Bool,
        now: Date
    ) throws -> RemotePairingAuthorization {
        callCount += 1
        guard bearerCredential == credential else { throw PairingError.invalidGrant }
        switch mode {
        case .authorized:
            return .init(peerID: peerID, grantID: grantID, role: .viewer)
        case .revoked:
            throw PairingError.grantRevoked
        case .expired:
            throw PairingError.grantExpired
        case .wrongPeer:
            return .init(peerID: .init(), grantID: grantID, role: .viewer)
        case .wrongGrant:
            return .init(peerID: peerID, grantID: .init(), role: .viewer)
        }
    }

    func setMode(_ mode: Mode) { self.mode = mode }
    func authorizationCalls() -> Int { callCount }
}

private actor SessionProjectionSpy: RemoteProjectionProviding {
    private var drainCallCount = 0
    private var disconnectCallCount = 0

    func connect(peerID: RemotePeerID) -> RemoteProjectionConnection {
        .init(peerID: peerID, snapshot: snapshotValue())
    }

    func disconnect(peerID: RemotePeerID) { disconnectCallCount += 1 }

    func drain(peerID: RemotePeerID, limit: Int) -> [RemoteProjectionEnvelope] {
        drainCallCount += 1
        return []
    }

    func snapshot() -> RemoteProjectionSnapshot { snapshotValue() }
    func drainCalls() -> Int { drainCallCount }
    func disconnectCalls() -> Int { disconnectCallCount }

    private func snapshotValue() -> RemoteProjectionSnapshot {
        .init(sessionID: nil, revision: 0, phase: .idle, statusMessage: "Ready", entries: [])
    }
}
