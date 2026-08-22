import Foundation
import RemotePairingAPI
import RemotePairingCore
import RemoteSharingAPI
import Testing

@Suite("Remote pairing registry")
struct PairingRegistryTests {
    @Test("A 256-bit invitation is single-use under a redemption race")
    func invitationRace() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 1_000)
        let invitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        #expect(invitation.fragmentCredential.count == 43)
        let redemption = PairingRedemption(
            invitationID: invitation.id,
            fragmentCredential: invitation.fragmentCredential,
            peerMetadata: .init(displayName: "iPad", userAgentSummary: "Safari")
        )
        let successes = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<2 {
                group.addTask {
                    (try? await registry.redeem(redemption, now: now.addingTimeInterval(1))) != nil
                }
            }
            var count = 0
            for await success in group where success { count += 1 }
            return count
        }
        #expect(successes == 1)
    }

    @Test("A viewer cannot mutate and a revoked operator cannot authorize")
    func roleAndRevocation() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 2_000)
        let viewer = try await pair(role: .viewer, registry: registry, now: now)
        await #expect(throws: PairingError.viewerIsReadOnly) {
            _ = try await registry.authorize(
                bearerCredential: viewer.bearerCredential,
                requiresMutation: true,
                now: now.addingTimeInterval(2)
            )
        }
        let operatorGrant = try await pair(role: .operator, registry: registry, now: now)
        await registry.revoke(grantID: operatorGrant.peer.grantID, now: now.addingTimeInterval(3))
        await #expect(throws: PairingError.grantRevoked) {
            _ = try await registry.authorize(
                bearerCredential: operatorGrant.bearerCredential,
                requiresMutation: false,
                now: now.addingTimeInterval(4)
            )
        }
    }

    @Test("Invitations and grants expire, and audit records contain no credentials")
    func expiryAndAuditRedaction() async throws {
        let registry = PairingRegistry(configuration: .init(invitationTTL: 15, grantTTL: 60))
        let now = Date(timeIntervalSince1970: 3_000)
        let expiredInvitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        let redemption = PairingRedemption(
            invitationID: expiredInvitation.id,
            fragmentCredential: expiredInvitation.fragmentCredential,
            peerMetadata: .init(displayName: "Phone", userAgentSummary: "Safari")
        )
        await #expect(throws: PairingError.invitationExpired) {
            _ = try await registry.redeem(redemption, now: now.addingTimeInterval(16))
        }
        let grant = try await pair(role: .viewer, registry: registry, now: now)
        await #expect(throws: PairingError.grantExpired) {
            _ = try await registry.authorize(
                bearerCredential: grant.bearerCredential,
                requiresMutation: false,
                now: now.addingTimeInterval(61)
            )
        }
        let encoded = try JSONEncoder().encode(await registry.auditLog())
        let audit = try #require(String(bytes: encoded, encoding: .utf8))
        #expect(!audit.contains(expiredInvitation.fragmentCredential))
        #expect(!audit.contains(grant.bearerCredential))
    }

    private func pair(
        role: RemoteRole,
        registry: PairingRegistry,
        now: Date
    ) async throws -> PairingGrant {
        let invitation = try await registry.issueMacApprovedInvitation(role: role, now: now)
        return try await registry.redeem(
            .init(
                invitationID: invitation.id,
                fragmentCredential: invitation.fragmentCredential,
                peerMetadata: .init(displayName: "Device", userAgentSummary: "Safari")
            ),
            now: now.addingTimeInterval(1)
        )
    }
}
