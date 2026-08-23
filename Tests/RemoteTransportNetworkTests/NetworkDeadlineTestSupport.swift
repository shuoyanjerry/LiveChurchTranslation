import Foundation
@preconcurrency import Network
import RemoteDiscoveryAPI
import RemoteProjectionCore
import RemoteTransportAPI
import RemoteTransportNetwork
import RemoteWebAssets

private typealias DeadlineContinuation = CheckedContinuation<Void, Error>

struct DeadlineServerFixture {
    let server: NWRemoteTransportServer
    let endpoint: RemoteEndpoint

    static func start(timeout: Duration) async throws -> Self {
        let sharing = RemoteSharingSwitch()
        await sharing.setEnabled(true)
        let pairing = ListenerPairingFake()
        let server = NWRemoteTransportServer(
            sharing: sharing,
            pairing: pairing,
            pairingManager: pairing,
            projection: RemoteProjectionStore(),
            commands: ListenerCommandFake(),
            assets: BundledRemoteWebAssetProvider(),
            limits: .init(httpHandshakeTimeout: timeout)
        )
        let endpoint = try await server.start(
            configuration: .init(
                advertisedHostName: "localhost",
                maximumConnections: 1,
                bonjour: .init(
                    name: "Deadline Test Reader",
                    type: "_churchtranslate._tcp",
                    textRecord: Data()
                )
            ))
        return .init(server: server, endpoint: endpoint)
    }

    func assetStatus() async throws -> Int? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        let session = URLSession(configuration: configuration)
        let (_, response) = try await session.data(from: endpoint.baseURL)
        return (response as? HTTPURLResponse)?.statusCode
    }
}

actor DeadlineTCPConnection {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "org.churchtranslation.remote.deadline-test")

    init(port: UInt16) throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw DeadlineTestError.invalidPort
        }
        connection = NWConnection(host: "127.0.0.1", port: endpointPort, using: .tcp)
    }

    func start() async throws {
        let connection = connection
        try await withCheckedThrowingContinuation { (continuation: DeadlineContinuation) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                case .cancelled:
                    connection.stateUpdateHandler = nil
                    continuation.resume(throwing: DeadlineTestError.connectionCancelled)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: DeadlineContinuation) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            )
        }
    }

    func cancel() { connection.cancel() }
}

func waitForConnectionRelease(_ events: AsyncStream<RemoteTransportEvent>) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        group.addTask {
            var sawOpenConnection = false
            for await event in events {
                guard case .connectionCountChanged(let count) = event else { continue }
                if count > 0 { sawOpenConnection = true }
                if sawOpenConnection, count == 0 { return }
            }
            throw DeadlineTestError.eventStreamEnded
        }
        group.addTask {
            try await Task.sleep(for: .seconds(3))
            throw DeadlineTestError.releaseTimedOut
        }
        _ = try await group.next()
        group.cancelAll()
    }
}

enum DeadlineTestError: Error {
    case connectionCancelled
    case eventStreamEnded
    case invalidPort
    case releaseTimedOut
}
