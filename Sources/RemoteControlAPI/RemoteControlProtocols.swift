public protocol RemoteSessionCommandHandling: Sendable {
    func handle(
        _ request: RemoteControlRequest,
        authorization: RemoteControlAuthorization
    ) async -> RemoteControlResult
}

public enum RemoteControlPolicy {
    public static func permitsMutation(_ authorization: RemoteControlAuthorization) -> Bool {
        authorization.role == .operator
    }
}
