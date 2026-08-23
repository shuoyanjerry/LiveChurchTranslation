import Foundation
@preconcurrency import Network
import RemoteDiscoveryAPI
import RemoteProjectionCore
import RemoteSharingAPI
import RemoteTransportAPI
@testable import RemoteTransportNetwork
import RemoteWebAssets
import Testing

@Suite struct StaleListenerGenerationTests {
    @Test("A stale listener failure cannot close the active replacement listener")
    func staleListenerFailureIsIgnored() async throws {
        let fixture = try await makeRunningServer()
        let server = fixture.server
        let endpoint = fixture.endpoint
        let activeListenerID = fixture.listenerID
        let staleListenerID = UUID()
        #expect(activeListenerID != staleListenerID)

        let connection = NWConnection(
            host: "127.0.0.1",
            port: try #require(NWEndpoint.Port(rawValue: endpoint.port)),
            using: .tcp
        )
        await server.accept(connection, listenerID: staleListenerID)
        #expect(await server.connections.isEmpty)

        await server.listenerStateChanged(
            .failed(.posix(.EADDRINUSE)),
            listenerID: staleListenerID
        )
        #expect(await server.activeListenerID == activeListenerID)
        #expect(await server.status() == .running(endpoint))

        await server.listenerStateChanged(.cancelled, listenerID: activeListenerID)
        #expect(await server.activeListenerID == nil)
        #expect(await server.status() == .stopped)
    }

    private func makeRunningServer() async throws -> StaleListenerFixture {
        let sharing = RemoteSharingSwitch()
        await sharing.setEnabled(true)
        let pairing = ListenerPairingFake()
        let server = NWRemoteTransportServer(
            sharing: sharing,
            pairing: pairing,
            pairingManager: pairing,
            projection: RemoteProjectionStore(),
            commands: ListenerCommandFake(),
            assets: BundledRemoteWebAssetProvider()
        )
        let endpoint = try await server.start(
            configuration: RemoteTransportConfiguration(
                advertisedHostName: "localhost",
                bonjour: .init(
                    name: "Generation Test Reader",
                    type: "_churchtranslate._tcp",
                    textRecord: Data()
                )
            )
        )
        let listenerID = try #require(await server.activeListenerID)
        return StaleListenerFixture(
            server: server,
            endpoint: endpoint,
            listenerID: listenerID
        )
    }
}

private struct StaleListenerFixture {
    let server: NWRemoteTransportServer
    let endpoint: RemoteEndpoint
    let listenerID: UUID
}
