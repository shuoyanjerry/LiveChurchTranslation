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

    @Test("The initial snapshot is blocked when authorization changes during upgrade")
    func initialSnapshotIsReauthorized() async throws {
        let pairing = ListenerPairingFake(maximumAuthorizationCalls: 1)
        let fixture = try await makeFixture(pairing: pairing)
        var request = URLRequest(url: fixture.endpoint.baseURL.appendingPathComponent("ws"))
        request.setValue(fixture.endpoint.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue("church_remote=\(pairing.credential)", forHTTPHeaderField: "Cookie")
        let socket = fixture.session.webSocketTask(with: request)
        socket.resume()

        do {
            _ = try await socket.receive()
            Issue.record("An initial snapshot escaped after the grant was rejected")
        } catch {}

        socket.cancel(with: .goingAway, reason: nil)
        await fixture.server.stop()
    }
}

extension NWRemoteTransportServerTests {
    private func makeFixture(
        pairing: ListenerPairingFake = ListenerPairingFake()
    ) async throws -> ServerFixture {
        let sharing = RemoteSharingSwitch()
        await sharing.setEnabled(true)
        let projection = RemoteProjectionStore()
        let server = NWRemoteTransportServer(
            sharing: sharing,
            pairing: pairing,
            pairingManager: pairing,
            projection: projection,
            commands: ListenerCommandFake(),
            assets: BundledRemoteWebAssetProvider(),
            limits: .init(httpHandshakeTimeout: .seconds(1))
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
        #expect(assetText.contains(#"<html lang="zh-CN">"#), "Chinese locale marker is missing")
        #expect(assetText.contains("<title>Live Church Translation</title>"))
    }
}

extension NWRemoteTransportServerTests {
    private func verifyWebSocket(_ fixture: ServerFixture) async throws {
        let socket = webSocket(for: fixture)
        socket.resume()
        try await verifyInitialSnapshot(socket)
        let sessionID = UUID()
        let entryID = UUID()
        let source = "恩典拯救我们。\n基督是主；我们一同祷告。"
        let target = "Grace saves us.\nChrist is Lord; let us pray together."
        await fixture.projection.beginSession(id: sessionID, message: "Listening")
        _ = try await fixture.projection.upsert(
            .init(
                id: entryID,
                sequence: 1,
                sourceText: source,
                targetText: target,
                createdAt: Date(),
                startedMilliseconds: 1_250,
                sourceLanguage: "zh-Hans",
                targetLanguage: "en"
            ))
        let received = try #require(try await receiveUpsert(socket))
        #expect(received.id == entryID)
        #expect(received.sequence == 1)
        #expect(received.sourceText == source)
        #expect(received.targetText == target)
        #expect(received.startedMilliseconds == 1_250)
        #expect(received.sourceLanguage == "zh-Hans")
        #expect(received.targetLanguage == "en")

        await fixture.pairing.revoke(grantID: fixture.pairing.grantID, now: Date())
        do {
            _ = try await socket.receive()
            Issue.record("A revoked WebSocket remained connected")
        } catch {}
        socket.cancel(with: .goingAway, reason: nil)
    }

    private func webSocket(for fixture: ServerFixture) -> URLSessionWebSocketTask {
        var request = URLRequest(url: fixture.endpoint.baseURL.appendingPathComponent("ws"))
        request.setValue(fixture.endpoint.baseURL.absoluteString, forHTTPHeaderField: "Origin")
        request.setValue(
            "church_remote=\(fixture.pairing.credential)",
            forHTTPHeaderField: "Cookie"
        )
        return fixture.session.webSocketTask(with: request)
    }

    private func verifyInitialSnapshot(_ socket: URLSessionWebSocketTask) async throws {
        let initial = try decode(try await socket.receive())
        guard case .snapshot = initial.payload else {
            socket.cancel(with: .protocolError, reason: nil)
            throw ListenerTestError.missingSnapshot
        }
    }

    private func receiveUpsert(
        _ socket: URLSessionWebSocketTask
    ) async throws -> RemoteTranscriptEntry? {
        for _ in 0..<3 {
            let envelope = try decode(try await socket.receive())
            if case .entryUpsert(_, let entry, _) = envelope.payload { return entry }
        }
        return nil
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
