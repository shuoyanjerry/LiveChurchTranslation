import Foundation
import RemoteDiscoveryAPI
import RemotePairingAPI
import RemoteSharingAPI
@testable import RemoteSharingFeature
import RemoteSharingFeatureAPI
import RemoteTransportAPI
import Testing

@Suite("Local sharing feature")
struct LocalNetworkSharingFeatureTests {
    @Test("Sharing is opt-in and invitations keep credentials in the fragment")
    func enableInviteAndDisable() async throws {
        let sharing = SharingFake()
        let pairing = PairingManagerFake()
        let transport = TransportFake()
        let feature = LocalNetworkSharingFeature(
            sharing: sharing,
            pairing: pairing,
            transport: transport,
            configuration: configuration
        )

        #expect(await feature.state() == .off)
        await feature.send(.toggle)
        #expect(await sharing.isEnabled())

        await feature.send(.createInvitation(role: .viewer))
        guard case .on(let endpoint, _, let invitation, _) = await feature.state() else {
            Issue.record("Expected active sharing")
            return
        }
        #expect(endpoint.host == "quiet-reader.local")
        #expect(invitation?.url.query == nil)
        #expect(invitation?.url.fragment?.hasPrefix("invite=") == true)

        await feature.send(.toggle)
        #expect(await feature.state() == .off)
        #expect(!(await sharing.isEnabled()))
        #expect(await transport.stopCount() == 1)
    }

    @Test("Cleartext sharing does not issue operator invitations")
    func rejectsOperatorInvitation() async {
        let sharing = SharingFake()
        let pairing = PairingManagerFake()
        let transport = TransportFake()
        let feature = LocalNetworkSharingFeature(
            sharing: sharing,
            pairing: pairing,
            transport: transport,
            configuration: configuration
        )

        await feature.send(.toggle)
        await feature.send(.createInvitation(role: .operator))

        #expect(await pairing.issuedRoles().isEmpty)
        guard case .on(_, _, let invitation, _) = await feature.state() else {
            Issue.record("Expected sharing to remain enabled")
            return
        }
        #expect(invitation == nil)
    }

    @Test("Local-network policy denial remains a typed recovery state")
    func localNetworkPermissionDenial() async {
        let sharing = SharingFake()
        let feature = LocalNetworkSharingFeature(
            sharing: sharing,
            pairing: PairingManagerFake(),
            transport: TransportFake(startError: .localNetworkPermissionDenied),
            configuration: configuration
        )

        await feature.send(.toggle)

        #expect(await feature.state() == .localNetworkPermissionDenied)
        #expect(!(await sharing.isEnabled()))
    }

    @Test("A delayed old failure cannot overwrite a successful retry")
    func staleEnableFailureDoesNotOverwriteRetry() async {
        let sharing = SharingFake()
        let transport = DelayedFailureThenSuccessTransport()
        let feature = LocalNetworkSharingFeature(
            sharing: sharing,
            pairing: PairingManagerFake(),
            transport: transport,
            configuration: configuration
        )
        let firstAttempt = Task { await feature.send(.toggle) }
        await transport.waitUntilFirstStartBegins()
        await feature.receive(.statusChanged(.localNetworkPermissionDenied))

        let retry = Task { await feature.send(.toggle) }
        await retry.value
        await transport.releaseFirstFailure()
        await firstAttempt.value

        guard case .on(let endpoint, _, _, _) = await feature.state() else {
            Issue.record("Expected the successful retry to remain authoritative")
            return
        }
        #expect(endpoint.port == 8_123)
        #expect(await sharing.isEnabled())
        #expect(await transport.startCount() == 2)
    }

    private var configuration: RemoteTransportConfiguration {
        RemoteTransportConfiguration(
            advertisedHostName: "quiet-reader.local",
            bonjour: RemoteBonjourDescriptor(
                name: "Quiet Liturgy Reader",
                type: "_churchtranslate._tcp",
                textRecord: Data()
            )
        )
    }
}

private actor SharingFake: RemoteSharingControlling {
    private var enabled = false
    func isEnabled() -> Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}

private actor TransportFake: RemoteTransportServing {
    private var stops = 0
    private let startError: RemoteTransportLifecycleError?

    init(startError: RemoteTransportLifecycleError? = nil) {
        self.startError = startError
    }

    func start(configuration: RemoteTransportConfiguration) throws -> RemoteEndpoint {
        if let startError { throw startError }
        return RemoteEndpoint(
            baseURL: URL(string: "http://\(configuration.advertisedHostName):8123")!,
            port: 8_123
        )
    }
    func stop() { stops += 1 }
    func status() -> RemoteTransportStatus { .stopped }
    func events() -> AsyncStream<RemoteTransportEvent> { AsyncStream { _ in } }
    func stopCount() -> Int { stops }
}

private actor PairingManagerFake: RemotePairingManaging {
    private var roles: [RemoteRole] = []

    func issueMacApprovedInvitation(
        role: RemoteRole,
        now: Date
    ) -> PairingInvitation {
        roles.append(role)
        return PairingInvitation(
            id: UUID(),
            role: role,
            fragmentCredential: String(repeating: "a", count: 43),
            expiresAt: now.addingTimeInterval(120)
        )
    }
    func activePeers(now _: Date) -> [RemotePeer] { [] }
    func snapshot(now _: Date) -> RemotePairingSnapshot {
        RemotePairingSnapshot(activePeers: [], pendingInvitationCount: 0)
    }
    func revoke(grantID _: RemoteGrantID, now _: Date) {}
    func revokeAll(now _: Date) {}
    func auditLog() -> [PairingAuditRecord] { [] }
    func events() -> AsyncStream<RemotePairingEvent> { AsyncStream { _ in } }
    func issuedRoles() -> [RemoteRole] { roles }
}
