import Foundation
import RemotePairingAPI
import RemotePairingCore
import RemoteSharingAPI
import Testing

@Suite("Remote pairing registry")
struct PairingRegistryTests {
    @Test("An operator invitation remains expiring and single-use under a redemption race")
    func operatorInvitationRace() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 1_000)
        let invitation = try await registry.issueMacApprovedInvitation(role: .operator, now: now)
        #expect(invitation.fragmentCredential.count == 43)
        #expect(invitation.expiresAt != nil)
        let redemption = pairingTestRedemption(invitation)
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for index in 0..<2 {
                group.addTask {
                    (try? await registry.redeem(
                        redemption,
                        clientBinding: try pairingTestBinding("192.168.10.\(20 + index)"),
                        now: now.addingTimeInterval(1)
                    )) != nil
                }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }
        #expect(successes == 1)
        await #expect(throws: PairingError.invitationAlreadyUsed) {
            _ = try await registry.redeem(
                redemption,
                clientBinding: pairingTestBinding("192.168.10.30"),
                now: now.addingTimeInterval(2)
            )
        }
    }

    @Test("A viewer cannot mutate and a revoked operator cannot authorize")
    func roleAndRevocation() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 2_000)
        let client = try pairingTestBinding()
        let viewer = try await pairForTest(
            role: .viewer,
            registry: registry,
            clientBinding: client,
            now: now
        )
        await #expect(throws: PairingError.viewerIsReadOnly) {
            _ = try await registry.authorize(
                bearerCredential: viewer.bearerCredential,
                clientBinding: client,
                requiresMutation: true,
                now: now.addingTimeInterval(2)
            )
        }
        let operatorGrant = try await pairForTest(
            role: .operator,
            registry: registry,
            clientBinding: client,
            now: now
        )
        await registry.revoke(grantID: operatorGrant.peer.grantID, now: now.addingTimeInterval(3))
        await #expect(throws: PairingError.grantRevoked) {
            _ = try await registry.authorize(
                bearerCredential: operatorGrant.bearerCredential,
                clientBinding: client,
                requiresMutation: false,
                now: now.addingTimeInterval(4)
            )
        }
    }

    @Test("Invitations and grants expire, and audit records contain no credentials")
    func expiryAndAuditRedaction() async throws {
        let registry = PairingRegistry(configuration: .init(invitationTTL: 15, grantTTL: 60))
        let now = Date(timeIntervalSince1970: 3_000)
        let client = try pairingTestBinding()
        let expiredInvitation = try await registry.issueMacApprovedInvitation(
            role: .operator,
            now: now
        )
        await #expect(throws: PairingError.invitationExpired) {
            _ = try await redeemForTest(
                expiredInvitation,
                registry: registry,
                clientBinding: client,
                now: now.addingTimeInterval(16)
            )
        }
        let grant = try await pairForTest(
            role: .operator,
            registry: registry,
            clientBinding: client,
            now: now
        )
        await #expect(throws: PairingError.grantExpired) {
            _ = try await registry.authorize(
                bearerCredential: grant.bearerCredential,
                clientBinding: client,
                requiresMutation: false,
                now: now.addingTimeInterval(61)
            )
        }
        let encoded = try JSONEncoder().encode(await registry.auditLog())
        let audit = try #require(String(bytes: encoded, encoding: .utf8))
        #expect(!audit.contains(expiredInvitation.fragmentCredential))
        #expect(!audit.contains(grant.bearerCredential))
    }
}

@Suite("Remote pairing client binding")
struct PairingClientBindingTests {
    @Test("A captured grant cannot be replayed by another LAN client")
    func clientBindingRejectsReplay() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 4_000)
        let redeemer = try pairingTestBinding("192.168.10.20")
        let attacker = try pairingTestBinding("192.168.10.21")
        let grant = try await pairForTest(
            role: .viewer,
            registry: registry,
            clientBinding: redeemer,
            now: now
        )

        _ = try await registry.authorize(
            bearerCredential: grant.bearerCredential,
            clientBinding: redeemer,
            requiresMutation: false,
            now: now.addingTimeInterval(2)
        )
        await #expect(throws: PairingError.invalidGrant) {
            _ = try await registry.authorize(
                bearerCredential: grant.bearerCredential,
                clientBinding: attacker,
                requiresMutation: false,
                now: now.addingTimeInterval(2)
            )
        }
    }
}
