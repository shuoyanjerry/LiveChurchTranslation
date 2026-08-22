public enum LocalSharingInvitationRole: Equatable, Sendable {
    case viewer
    case `operator`
}

public enum LocalSharingIntent: Equatable, Sendable {
    case toggle
    case createInvitation(role: LocalSharingInvitationRole)
    case revoke(peerID: String)
    case revokeAll
}

public protocol LocalSharingFeature: Sendable {
    func state() async -> LocalSharingViewState
    func events() async -> AsyncStream<LocalSharingViewState>
    func send(_ intent: LocalSharingIntent) async
}

public typealias LocalSharingIntentHandler = @MainActor (LocalSharingIntent) -> Void
