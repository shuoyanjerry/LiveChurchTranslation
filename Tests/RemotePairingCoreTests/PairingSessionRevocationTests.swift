import Foundation
import RemotePairingAPI
import RemotePairingCore
import Testing

@Suite("Pairing session revocation")
struct PairingSessionRevocationTests {
    @Test("Global revocation invalidates a viewer link and every issued grant")
    func globalRevocation() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 3_500)
        let client = try pairingTestBinding("192.168.40.20")
        let invitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        let grant = try await redeemForTest(
            invitation,
            registry: registry,
            clientBinding: client,
            now: now.addingTimeInterval(1)
        )

        await registry.revokeAll(now: now.addingTimeInterval(2))
        let stopped = await registry.snapshot(now: now.addingTimeInterval(2))
        #expect(stopped.activePeers.isEmpty)
        #expect(stopped.pendingInvitationCount == 0)
        await #expect(throws: PairingError.invalidGrant) {
            _ = try await registry.authorize(
                bearerCredential: grant.bearerCredential,
                clientBinding: client,
                requiresMutation: false,
                now: now.addingTimeInterval(3)
            )
        }
        await #expect(throws: PairingError.invalidInvitation) {
            _ = try await redeemForTest(
                invitation,
                registry: registry,
                clientBinding: pairingTestBinding("192.168.40.21"),
                now: now.addingTimeInterval(3)
            )
        }
    }

    @Test("A restarted session rotates the secret and permanently rejects the old link")
    func restartRotatesSecret() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 3_750)
        let oldInvitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        await registry.revokeAll(now: now.addingTimeInterval(1))
        let newInvitation = try await registry.issueMacApprovedInvitation(
            role: .viewer,
            now: now.addingTimeInterval(2)
        )

        #expect(newInvitation.id != oldInvitation.id)
        #expect(newInvitation.fragmentCredential != oldInvitation.fragmentCredential)
        await #expect(throws: PairingError.invalidInvitation) {
            _ = try await redeemForTest(
                oldInvitation,
                registry: registry,
                clientBinding: pairingTestBinding("192.168.40.22"),
                now: now.addingTimeInterval(3)
            )
        }
        _ = try await redeemForTest(
            newInvitation,
            registry: registry,
            clientBinding: pairingTestBinding("192.168.40.22"),
            now: now.addingTimeInterval(3)
        )
    }
}
