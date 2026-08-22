import Foundation
import RemoteDiscoveryAPI
import RemoteProjectionCore
import RemoteSharingAPI
import RemoteTransportAPI
import RemoteTransportNetwork
import RemoteWebAssets
import Testing

@Suite("Network.framework remote server")
struct NWRemoteTransportServerTests {
    @Test(
        "A random-port listener serves assets and streams snapshot plus live delta", .timeLimit(.minutes(1)))
    func listenerAndWebSocket() async throws {
        let fixture = try await makeFixture()
        try await verifyAsset(fixture)
        try await verifyWebSocket(fixture)
        await fixture.server.stop()
        #expect(await fixture.server.status() == .stopped)
    }

    private func makeFixture() async throws -> ServerFixture {
        let sharing = RemoteSharingSwitch()
        await sharing.setEnabled(true)
        let pairing = ListenerPairingFake()
        let projection = RemoteProjectionStore()
        let server = NWRemoteTransportServer(
            sharing: sharing,
            pairing: pairing,
            pairingManager: pairing,
            projection: projection,
            commands: ListenerCommandFake(),
            assets: BundledRemoteWebAssetProvider()
        )
        let endpoint = try await server.start(
            configuration: .init(
                advertisedHostName: "localhost",
                bonjour: .init(name: "Test Reader", type: "_churchtranslate._tcp", textRecord: Data())
            ))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: configuration)
        #expect(endpoint.port > 0)
        return ServerFixture(
            server: server,
            pairing: pairing,
            projection: projection,
            endpoint: endpoint,
            session: session
        )
    }

    private func verifyAsset(_ fixture: ServerFixture) async throws {
        let (assetData, response) = try await fixture.session.data(from: fixture.endpoint.baseURL)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
        let assetText = try #require(String(bytes: assetData, encoding: .utf8))
        #expect(assetText.contains("Quiet Liturgy"))
    }

    private func verifyWebSocket(_ fixture: ServerFixture) async throws {
        var request = URLRequest(url: fixture.endpoint.baseURL.appendingPathComponent("ws"))
        request.setValue(fixture.endpoint.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(
            "church_remote=\(fixture.pairing.credential)",
            forHTTPHeaderField: "Cookie"
        )
        let socket = fixture.session.webSocketTask(with: request)
        socket.resume()
        let initial = try decode(try await socket.receive())
        guard case .snapshot = initial.payload else {
            socket.cancel(with: .protocolError, reason: nil)
            throw ListenerTestError.missingSnapshot
        }
        await fixture.projection.beginSession(id: UUID(), message: "Listening")
        _ = try await fixture.projection.upsert(
            .init(
                id: UUID(),
                sequence: 1,
                sourceText: "恩典",
                targetText: "Grace",
                createdAt: Date()
            ))
        var receivedUpsert = false
        for _ in 0..<3 {
            let envelope = try decode(try await socket.receive())
            if case .entryUpsert = envelope.payload {
                receivedUpsert = true
                break
            }
        }
        #expect(receivedUpsert)
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func decode(_ message: URLSessionWebSocketTask.Message) throws -> RemoteProjectionEnvelope {
        let data: Data
        switch message {
        case .data(let value): data = value
        case .string(let value): data = Data(value.utf8)
        @unknown default: throw RemoteTransportError.invalidWebSocketFrame
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RemoteProjectionEnvelope.self, from: data)
    }
}

private struct ServerFixture {
    let server: NWRemoteTransportServer
    let pairing: ListenerPairingFake
    let projection: RemoteProjectionStore
    let endpoint: RemoteEndpoint
    let session: URLSession
}

private enum ListenerTestError: Error {
    case missingSnapshot
}
