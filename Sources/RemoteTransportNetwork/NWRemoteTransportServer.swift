import Foundation
@preconcurrency import Network
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI
import RemoteTransportAPI
import RemoteWebAssetsAPI

public actor NWRemoteTransportServer: RemoteTransportServing {
    let sharing: any RemoteSharingControlling
    let pairing: any RemotePairingServing
    let pairingManager: any RemotePairingManaging
    let projection: any RemoteProjectionProviding & RemoteProjectionUpdating
    let commands: any RemoteSessionCommandHandling
    let assets: any RemoteWebAssetProviding
    let limits: RemoteTransportLimits
    private let queue = DispatchQueue(label: "org.churchtranslation.remote.listener")
    var listener: NWListener?
    var activeListenerID: UUID?
    var components: RemoteServerComponents?
    var connections: [UUID: NWRemoteConnectionHandler] = [:]
    var currentStatus = RemoteTransportStatus.stopped
    var startContinuation: CheckedContinuation<RemoteEndpoint, any Error>?
    var eventContinuations: [UUID: AsyncStream<RemoteTransportEvent>.Continuation] = [:]
    var heartbeatTask: Task<Void, Never>?
    var activeConfiguration: RemoteTransportConfiguration?

    public init(
        sharing: any RemoteSharingControlling,
        pairing: any RemotePairingServing,
        pairingManager: any RemotePairingManaging,
        projection: any RemoteProjectionProviding & RemoteProjectionUpdating,
        commands: any RemoteSessionCommandHandling,
        assets: any RemoteWebAssetProviding,
        limits: RemoteTransportLimits = RemoteTransportLimits()
    ) {
        self.sharing = sharing
        self.pairing = pairing
        self.pairingManager = pairingManager
        self.projection = projection
        self.commands = commands
        self.assets = assets
        self.limits = limits
    }

    public func start(configuration: RemoteTransportConfiguration) async throws -> RemoteEndpoint {
        guard listener == nil else { throw RemoteTransportLifecycleError.alreadyRunning }
        guard isValid(configuration) else { throw RemoteTransportLifecycleError.invalidConfiguration }
        setStatus(.starting)
        activeConfiguration = configuration
        return try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
            do {
                let newListener: NWListener
                if configuration.preferredPort == 0 {
                    newListener = try NWListener(using: .tcp)
                } else {
                    guard let port = NWEndpoint.Port(rawValue: configuration.preferredPort) else {
                        throw RemoteTransportLifecycleError.invalidConfiguration
                    }
                    newListener = try NWListener(using: .tcp, on: port)
                }
                listener = newListener
                let listenerID = UUID()
                activeListenerID = listenerID
                NWListenerBonjourAttachment.attach(
                    descriptor: configuration.bonjour,
                    to: newListener
                )
                installHandlers(on: newListener, listenerID: listenerID)
                newListener.start(queue: queue)
            } catch {
                failStart(caught: error)
            }
        }
    }

    public func stop() async {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        let activeListener = listener
        listener = nil
        activeListenerID = nil
        activeListener?.cancel()
        startContinuation?.resume(throwing: RemoteTransportLifecycleError.listenerFailed("Stopped"))
        startContinuation = nil
        let openConnections = connections.values
        connections.removeAll()
        for connection in openConnections { await connection.close() }
        components = nil
        activeConfiguration = nil
        await pairingManager.revokeAll(now: Date())
        setStatus(.stopped)
        emit(.connectionCountChanged(0))
    }

    public func status() -> RemoteTransportStatus { currentStatus }

    public func events() -> AsyncStream<RemoteTransportEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            eventContinuations[id] = continuation
            continuation.yield(.statusChanged(currentStatus))
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeEventContinuation(id) }
            }
        }
    }
}
