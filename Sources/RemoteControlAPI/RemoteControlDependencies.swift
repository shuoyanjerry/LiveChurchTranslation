public protocol RemoteRevisionReading: Sendable {
    func currentRemoteRevision() async -> UInt64
}

public protocol RemoteSessionMutationTarget: Sendable {
    func startRemoteSession() async throws
    func stopRemoteSession() async throws
}
