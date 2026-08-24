import Foundation
import RemotePairingAPI
import RemotePairingCore
import Testing

@Suite("Reusable viewer pairing")
struct PairingReusableViewerTests {}

extension PairingReusableViewerTests {
    @Test("The production default admits a one-hundred-listener audience")
    func defaultAudienceCapacity() async throws {
        let registry = PairingRegistry()
        let now = Date(timeIntervalSince1970: 1_400)
        let invitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        let grants = try await concurrentlyRedeem(
            invitation,
            registry: registry,
            count: 100,
            now: now.addingTimeInterval(1)
        )

        #expect(grants.count == 100)
        #expect(await registry.snapshot(now: now.addingTimeInterval(2)).activePeers.count == 100)

        let replacementAudience = try await concurrentlyRedeem(
            invitation,
            registry: registry,
            count: 100,
            addressOffset: 120,
            now: now.addingTimeInterval(3)
        )
        #expect(replacementAudience.count == 100)
        #expect(await registry.snapshot(now: now.addingTimeInterval(4)).activePeers.count == 200)
    }

    @Test("A viewer invitation is session-lived and reusable by concurrent clients")
    func concurrentRedemption() async throws {
        let registry = PairingRegistry(configuration: .init(maximumActiveGrants: 16))
        let issuedAt = Date(timeIntervalSince1970: 1_500)
        let invitation = try await registry.issueMacApprovedInvitation(
            role: .viewer,
            now: issuedAt
        )
        #expect(invitation.expiresAt == nil)
        let redeemAt = issuedAt.addingTimeInterval(365 * 24 * 60 * 60)
        let grants = try await concurrentlyRedeem(
            invitation,
            registry: registry,
            count: 8,
            now: redeemAt
        )

        #expect(grants.count == 8)
        let snapshot = await registry.snapshot(now: redeemAt)
        #expect(snapshot.activePeers.count == 8)
        #expect(snapshot.pendingInvitationCount == 1)
        for (client, grant) in grants {
            #expect(grant.peer.expiresAt == nil)
            _ = try await registry.authorize(
                bearerCredential: grant.bearerCredential,
                clientBinding: client,
                requiresMutation: false,
                now: redeemAt.addingTimeInterval(365 * 24 * 60 * 60)
            )
        }
    }

    @Test("Reusable redemption enforces grant capacity on every scan")
    func grantCapacity() async throws {
        let registry = PairingRegistry(configuration: .init(maximumActiveGrants: 3))
        let now = Date(timeIntervalSince1970: 1_750)
        let invitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        let grants = try await concurrentlyRedeem(
            invitation,
            registry: registry,
            count: 3,
            now: now.addingTimeInterval(1)
        )
        let replacement = try await redeemForTest(
            invitation,
            registry: registry,
            clientBinding: grants[0].0,
            now: now.addingTimeInterval(2)
        )
        #expect(await registry.snapshot(now: now.addingTimeInterval(2)).activePeers.count == 3)
        await #expect(throws: PairingError.capacityReached) {
            _ = try await redeemForTest(
                invitation,
                registry: registry,
                clientBinding: pairingTestBinding("192.168.30.30"),
                now: now.addingTimeInterval(3)
            )
        }

        await registry.revoke(grantID: replacement.peer.grantID, now: now.addingTimeInterval(4))
        _ = try await redeemForTest(
            invitation,
            registry: registry,
            clientBinding: pairingTestBinding("192.168.30.30"),
            now: now.addingTimeInterval(5)
        )
    }

    @Test("Repeated scans from one client replace its viewer grant without consuming capacity")
    func sameClientRedemptionIsIdempotent() async throws {
        let registry = PairingRegistry(configuration: .init(maximumActiveGrants: 3))
        let now = Date(timeIntervalSince1970: 1_900)
        let client = try pairingTestBinding("192.168.60.20")
        let invitation = try await registry.issueMacApprovedInvitation(role: .viewer, now: now)
        var grants: [PairingGrant] = []
        for scan in 0..<100 {
            grants.append(
                try await redeemForTest(
                    invitation,
                    registry: registry,
                    clientBinding: client,
                    now: now.addingTimeInterval(Double(scan + 1))
                )
            )
        }

        let snapshot = await registry.snapshot(now: now.addingTimeInterval(101))
        #expect(snapshot.activePeers.count == 1)
        let audit = await registry.auditLog()
        #expect(audit.filter { $0.action == .paired }.count == 100)
        #expect(audit.filter { $0.action == .revoked }.count == 99)
        _ = try await registry.authorize(
            bearerCredential: grants[99].bearerCredential,
            clientBinding: client,
            requiresMutation: false,
            now: now.addingTimeInterval(101)
        )
        await #expect(throws: PairingError.invalidGrant) {
            _ = try await registry.authorize(
                bearerCredential: grants[0].bearerCredential,
                clientBinding: client,
                requiresMutation: false,
                now: now.addingTimeInterval(101)
            )
        }
    }
}

private func concurrentlyRedeem(
    _ invitation: PairingInvitation,
    registry: PairingRegistry,
    count: Int,
    addressOffset: Int = 20,
    now: Date
) async throws -> [(RemotePairingClientBinding, PairingGrant)] {
    try await withThrowingTaskGroup(
        of: (RemotePairingClientBinding, PairingGrant).self,
        returning: [(RemotePairingClientBinding, PairingGrant)].self
    ) { group in
        for index in 0..<count {
            group.addTask {
                let thirdOctet = 20 + ((addressOffset + index) / 250)
                let fourthOctet = 1 + ((addressOffset + index) % 250)
                let client = try pairingTestBinding("192.168.\(thirdOctet).\(fourthOctet)")
                let grant = try await redeemForTest(
                    invitation,
                    registry: registry,
                    clientBinding: client,
                    now: now
                )
                return (client, grant)
            }
        }
        var results: [(RemotePairingClientBinding, PairingGrant)] = []
        for try await result in group { results.append(result) }
        return results
    }
}
