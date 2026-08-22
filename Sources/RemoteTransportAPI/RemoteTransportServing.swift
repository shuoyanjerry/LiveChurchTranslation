public protocol RemoteTransportServing: Sendable {
    func start(configuration: RemoteTransportConfiguration) async throws -> RemoteEndpoint
    func stop() async
    func status() async -> RemoteTransportStatus
    func events() async -> AsyncStream<RemoteTransportEvent>
}
