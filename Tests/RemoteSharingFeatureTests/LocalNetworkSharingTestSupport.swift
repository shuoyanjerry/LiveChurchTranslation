import Foundation
import RemoteDiscoveryAPI
import RemotePairingAPI
import RemoteSharingAPI
import RemoteSharingFeatureAPI
import RemoteTransportAPI
import Testing

@testable import RemoteSharingFeature

func makeSharingFeature(
    sharing: any RemoteSharingControlling = SharingFake(),
    pairing: any RemotePairingManaging = PairingManagerFake(),
    transport: any RemoteTransportServing = TransportFake()
) -> LocalNetworkSharingFeature {
    LocalNetworkSharingFeature(
        sharing: sharing,
        pairing: pairing,
        transport: transport,
        configuration: RemoteTransportConfiguration(
            advertisedHostName: "live-church-translation.local",
            bonjour: RemoteBonjourDescriptor(
                name: "Live Church Translation",
                type: "_churchtranslate._tcp",
                textRecord: Data()
            )
        )
    )
}

actor SharingFake: RemoteSharingControlling {
    private var enabled = false
    func isEnabled() -> Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}

actor TransportFake: RemoteTransportServing {
    private var stops = 0
    private var configurations: [RemoteTransportConfiguration] = []
    private let startError: RemoteTransportLifecycleError?

    init(startError: RemoteTransportLifecycleError? = nil) {
        self.startError = startError
    }

    func start(configuration: RemoteTransportConfiguration) throws -> RemoteEndpoint {
        configurations.append(configuration)
        if let startError { throw startError }
        return RemoteEndpoint(
            baseURL: URL(string: "http://\(configuration.advertisedHostName):8123")!,
            port: 8_123
        )
    }
    func stop() { stops += 1 }
    func status() -> RemoteTransportStatus { .stopped }
    func events() -> AsyncStream<RemoteTransportEvent> { AsyncStream { _ in } }
    func stopCount() -> Int { stops }
    func startedConfigurations() -> [RemoteTransportConfiguration] { configurations }
}

actor PairingManagerFake: RemotePairingManaging {
    private var roles: [RemoteRole] = []
    private var globalRevocations = 0

    func issueMacApprovedInvitation(
        role: RemoteRole,
        now: Date
    ) -> PairingInvitation {
        roles.append(role)
        return PairingInvitation(
            id: UUID(),
            role: role,
            fragmentCredential: String(repeating: "a", count: 43),
            expiresAt: role == .viewer ? nil : now.addingTimeInterval(120)
        )
    }
    func activePeers(now _: Date) -> [RemotePeer] { [] }
    func snapshot(now _: Date) -> RemotePairingSnapshot {
        RemotePairingSnapshot(activePeers: [], pendingInvitationCount: 0)
    }
    func revokeInvitation(id _: UUID, now _: Date) {}
    func revoke(grantID _: RemoteGrantID, now _: Date) {}
    func revokeAll(now _: Date) { globalRevocations += 1 }
    func auditLog() -> [PairingAuditRecord] { [] }
    func events() -> AsyncStream<RemotePairingEvent> { AsyncStream { _ in } }
    func issuedRoles() -> [RemoteRole] { roles }
    func revokeAllCount() -> Int { globalRevocations }
}

func currentInvitation(
    from feature: LocalNetworkSharingFeature
) async throws -> LocalSharingInvitation {
    guard case .on(_, _, let invitation, _) = await feature.state() else {
        Issue.record("Expected sharing to be enabled")
        throw PairingError.invalidInvitation
    }
    return try #require(invitation)
}

func redemption(
    from invitation: LocalSharingInvitation,
    displayName: String
) throws -> PairingRedemption {
    let fragment = try #require(invitation.url.fragment)
    let prefix = "invite="
    guard fragment.hasPrefix(prefix) else { throw PairingError.invalidInvitation }
    let fields = fragment.dropFirst(prefix.count).split(
        separator: ".",
        maxSplits: 1,
        omittingEmptySubsequences: false
    )
    guard fields.count == 2, let id = UUID(uuidString: String(fields[0])) else {
        throw PairingError.invalidInvitation
    }
    return PairingRedemption(
        invitationID: id,
        fragmentCredential: String(fields[1]),
        peerMetadata: .init(displayName: displayName, userAgentSummary: "Safari")
    )
}

func sharingTestBinding(_ value: String) throws -> RemotePairingClientBinding {
    try #require(RemotePairingClientBinding(rawValue: value))
}
