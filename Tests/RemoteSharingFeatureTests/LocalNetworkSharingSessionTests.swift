import Foundation
import RemotePairingAPI
import RemotePairingCore
import RemoteSharingFeatureAPI
import RemoteTransportAPI
import Testing

@testable import RemoteSharingFeature

@Suite("Local sharing session lifecycle")
struct LocalNetworkSharingSessionTests {
    @Test("A transient listener failure retries on the same URL and preserves the old QR")
    func failureRetryPreservesViewerInvitation() async throws {
        let registry = PairingRegistry()
        let transport = TransportFake()
        let feature = makeSharingFeature(pairing: registry, transport: transport)
        await feature.send(.toggle)
        await feature.send(.createInvitation(role: .viewer))
        let oldInvitation = try await currentInvitation(from: feature)
        let oldRedemption = try redemption(from: oldInvitation, displayName: "Retry iPhone")

        await feature.receive(.statusChanged(.failed(message: "transient")))
        let interrupted = await registry.snapshot(now: Date())
        #expect(interrupted.pendingInvitationCount == 1)
        await feature.send(.toggle)

        let restoredInvitation = try await currentInvitation(from: feature)
        #expect(restoredInvitation.url == oldInvitation.url)
        let starts = await transport.startedConfigurations()
        #expect(starts.count == 2)
        #expect(starts[0].preferredPort == 0)
        #expect(starts[1].preferredPort == 8_123)
        _ = try await registry.redeem(
            oldRedemption,
            clientBinding: sharingTestBinding("192.168.50.30"),
            now: Date()
        )
    }

    @Test("Stopping and restarting rotates the link and rejects every old capability")
    func stopRestartInvalidatesOldViewerCapabilities() async throws {
        let registry = PairingRegistry()
        let feature = makeSharingFeature(pairing: registry)
        let oldClient = try sharingTestBinding("192.168.50.20")
        let pairedAt = Date()
        await feature.send(.toggle)
        await feature.send(.createInvitation(role: .viewer))
        let oldInvitation = try await currentInvitation(from: feature)
        let oldRedemption = try redemption(from: oldInvitation, displayName: "Old iPhone")
        let oldGrant = try await registry.redeem(
            oldRedemption,
            clientBinding: oldClient,
            now: pairedAt
        )

        await feature.send(.toggle)
        #expect(await feature.state() == .off)
        try await expectStoppedCapabilitiesRejected(
            registry: registry,
            redemption: oldRedemption,
            grant: oldGrant,
            client: oldClient,
            now: pairedAt.addingTimeInterval(1)
        )
        try await restartAndExpectRotation(
            feature: feature,
            registry: registry,
            oldInvitation: oldInvitation,
            oldRedemption: oldRedemption,
            now: pairedAt.addingTimeInterval(2)
        )
    }

    @Test("Disconnecting everyone also clears the reusable invitation")
    func revokeAllClearsInvitation() async throws {
        let pairing = PairingManagerFake()
        let feature = makeSharingFeature(pairing: pairing)

        await feature.send(.toggle)
        await feature.send(.createInvitation(role: .viewer))
        _ = try await currentInvitation(from: feature)
        await feature.send(.revokeAll)

        guard case .on(_, _, let invitation, _) = await feature.state() else {
            Issue.record("Expected sharing to remain enabled")
            return
        }
        #expect(invitation == nil)
        #expect(await pairing.revokeAllCount() == 1)
    }
}

private func expectStoppedCapabilitiesRejected(
    registry: PairingRegistry,
    redemption: PairingRedemption,
    grant: PairingGrant,
    client: RemotePairingClientBinding,
    now: Date
) async throws {
    let snapshot = await registry.snapshot(now: now)
    #expect(snapshot.activePeers.isEmpty)
    #expect(snapshot.pendingInvitationCount == 0)
    await #expect(throws: PairingError.invalidGrant) {
        _ = try await registry.authorize(
            bearerCredential: grant.bearerCredential,
            clientBinding: client,
            requiresMutation: false,
            now: now
        )
    }
    await #expect(throws: PairingError.invalidInvitation) {
        _ = try await registry.redeem(
            redemption,
            clientBinding: sharingTestBinding("192.168.50.21"),
            now: now
        )
    }
}

private func restartAndExpectRotation(
    feature: LocalNetworkSharingFeature,
    registry: PairingRegistry,
    oldInvitation: LocalSharingInvitation,
    oldRedemption: PairingRedemption,
    now: Date
) async throws {
    let client = try sharingTestBinding("192.168.50.22")
    await feature.send(.toggle)
    await feature.send(.createInvitation(role: .viewer))
    let newInvitation = try await currentInvitation(from: feature)
    #expect(newInvitation.url != oldInvitation.url)
    await #expect(throws: PairingError.invalidInvitation) {
        _ = try await registry.redeem(
            oldRedemption,
            clientBinding: client,
            now: now
        )
    }
    _ = try await registry.redeem(
        redemption(from: newInvitation, displayName: "New iPad"),
        clientBinding: client,
        now: now
    )
}
