import Foundation
import RemoteDiscoveryAPI
import RemotePairingAPI
import RemoteSharingAPI
import RemoteSharingFeature
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
    func start(configuration: RemoteTransportConfiguration) throws -> RemoteEndpoint {
        RemoteEndpoint(
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
    func issueMacApprovedInvitation(
        role: RemoteRole,
        now: Date
    ) -> PairingInvitation {
        PairingInvitation(
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
}
