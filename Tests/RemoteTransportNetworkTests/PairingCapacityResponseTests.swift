import Foundation
import RemotePairingAPI
import RemoteSharingAPI
import RemoteTransportNetwork
import Testing

@Suite("Pairing capacity response")
struct PairingCapacityResponseTests {
    @Test("A full listener returns an empty 429 without disclosing pairing state")
    func capacityMapsToTooManyRequests() async throws {
        let response = await makeRouter(pairing: CapacityPairing()).handle(
            try pairingRequest(),
            peer: .init(host: "192.168.1.15")
        )
        #expect(response.status == 429)
        #expect(response.reason == "Too Many Requests")
        #expect(response.body.isEmpty)
    }

    @Test("An invalid invitation remains an indistinguishable empty bad request")
    func invalidInvitationRemainsGeneric() async throws {
        let response = await makeRouter(pairing: ViewerPairing()).handle(
            try pairingRequest(),
            peer: .init(host: "192.168.1.15")
        )
        #expect(response.status == 400)
        #expect(response.reason == "Bad Request")
        #expect(response.body.isEmpty)
    }

    private func makeRouter(pairing: any RemotePairingServing) -> RemoteHTTPRouter {
        RemoteHTTPRouter(
            security: .init(
                configuration: .init(
                    allowedHosts: ["reader.local:9000"],
                    allowedOrigins: ["http://reader.local:9000"]
                )
            ),
            sharing: EnabledSharing(),
            pairing: pairing,
            projection: ProjectionFake(),
            commands: CommandSpy(),
            assets: EmptyAssets()
        )
    }

    private func pairingRequest() throws -> RemoteHTTPRequest {
        let redemption = PairingRedemption(
            invitationID: UUID(),
            fragmentCredential: String(repeating: "i", count: 43),
            peerMetadata: .init(displayName: "iPhone", userAgentSummary: "Safari")
        )
        return RemoteHTTPRequest(
            method: "POST",
            target: "/api/pair",
            path: "/api/pair",
            query: nil,
            headers: [
                "host": ["reader.local:9000"],
                "origin": ["http://reader.local:9000"],
                "content-type": ["application/json"],
            ],
            body: try JSONEncoder().encode(redemption)
        )
    }
}

private struct CapacityPairing: RemotePairingServing {
    func redeem(
        _ redemption: PairingRedemption,
        clientBinding: RemotePairingClientBinding,
        now: Date
    ) async throws -> PairingGrant {
        throw PairingError.capacityReached
    }

    func authorize(
        bearerCredential: String,
        clientBinding: RemotePairingClientBinding,
        requiresMutation: Bool,
        now: Date
    ) async throws -> RemotePairingAuthorization {
        throw PairingError.invalidGrant
    }
}
