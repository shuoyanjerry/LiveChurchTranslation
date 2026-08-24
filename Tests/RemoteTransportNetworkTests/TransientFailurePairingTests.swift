import RemoteProjectionCore
import RemoteSharingAPI
@testable import RemoteTransportNetwork
import RemoteWebAssets
import Testing

@Suite("Transient listener failure")
struct TransientFailurePairingTests {
    @Test("Failure preserves pairing while explicit stop revokes it")
    func failureAndStopHaveDistinctSecurityBoundaries() async {
        let pairing = ListenerPairingFake()
        let server = NWRemoteTransportServer(
            sharing: RemoteSharingSwitch(),
            pairing: pairing,
            pairingManager: pairing,
            projection: RemoteProjectionStore(),
            commands: ListenerCommandFake(),
            assets: BundledRemoteWebAssetProvider()
        )

        await server.failRunningServer("transient")
        #expect(await server.status() == .failed(message: "transient"))
        #expect(!(await pairing.isRevoked()))

        await server.stop()
        #expect(await server.status() == .stopped)
        #expect(await pairing.isRevoked())
    }
}
