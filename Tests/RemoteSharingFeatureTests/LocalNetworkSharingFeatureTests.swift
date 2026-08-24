import RemoteSharingFeatureAPI
import RemoteTransportAPI
import Testing

@testable import RemoteSharingFeature

@Suite("Local sharing feature")
struct LocalNetworkSharingFeatureTests {
    @Test("Sharing is opt-in and reuses one fragment-only viewer invitation")
    func enableInviteAndDisable() async throws {
        let sharing = SharingFake()
        let pairing = PairingManagerFake()
        let transport = TransportFake()
        let feature = makeSharingFeature(
            sharing: sharing,
            pairing: pairing,
            transport: transport
        )

        #expect(await feature.state() == .off)
        await feature.send(.toggle)
        #expect(await sharing.isEnabled())
        await feature.send(.createInvitation(role: .viewer))
        let invitation = try await currentInvitation(from: feature)
        #expect(invitation.url.host == "live-church-translation.local")
        #expect(invitation.url.query == nil)
        #expect(invitation.url.fragment?.hasPrefix("invite=") == true)

        await feature.send(.createInvitation(role: .viewer))
        let repeatedInvitation = try await currentInvitation(from: feature)
        #expect(repeatedInvitation.url == invitation.url)
        #expect(await pairing.issuedRoles() == [.viewer])

        await feature.send(.toggle)
        #expect(await feature.state() == .off)
        #expect(!(await sharing.isEnabled()))
        #expect(await transport.stopCount() == 1)
        #expect(await pairing.revokeAllCount() == 1)
    }

    @Test("Cleartext sharing rejects operators without replacing the viewer invitation")
    func rejectsOperatorInvitation() async throws {
        let pairing = PairingManagerFake()
        let feature = makeSharingFeature(pairing: pairing)

        await feature.send(.toggle)
        await feature.send(.createInvitation(role: .viewer))
        let viewerInvitation = try await currentInvitation(from: feature)
        await feature.send(.createInvitation(role: .operator))

        #expect(await pairing.issuedRoles() == [.viewer])
        guard case .on(_, _, let invitation, _) = await feature.state() else {
            Issue.record("Expected sharing to remain enabled")
            return
        }
        #expect(invitation == viewerInvitation)
    }

    @Test("Local-network policy denial remains a typed recovery state")
    func localNetworkPermissionDenial() async {
        let sharing = SharingFake()
        let feature = makeSharingFeature(
            sharing: sharing,
            transport: TransportFake(startError: .localNetworkPermissionDenied)
        )

        await feature.send(.toggle)

        #expect(await feature.state() == .localNetworkPermissionDenied)
        #expect(!(await sharing.isEnabled()))
    }

    @Test("A listener failure becomes a fixed presentation state")
    func listenerFailureIsRedacted() async {
        let sharing = SharingFake()
        let feature = makeSharingFeature(
            sharing: sharing,
            transport: TransportFake(
                startError: .listenerFailed("/Users/private/raw-listener-error")
            )
        )

        await feature.send(.toggle)

        #expect(await feature.state() == .failed)
        #expect(!(await sharing.isEnabled()))
    }

    @Test("A transport event cannot place its message in presentation state")
    func transportFailureMessageIsRedacted() async {
        let feature = makeSharingFeature()
        await feature.send(.toggle)

        await feature.receive(
            .statusChanged(
                .failed(message: "/Users/private/raw-transport-error socket=192.168.1.2")
            )
        )

        #expect(await feature.state() == .failed)
    }

    @Test("A delayed old failure cannot overwrite a successful retry")
    func staleEnableFailureDoesNotOverwriteRetry() async {
        let sharing = SharingFake()
        let transport = DelayedFailureThenSuccessTransport()
        let feature = makeSharingFeature(sharing: sharing, transport: transport)
        let firstAttempt = Task { await feature.send(.toggle) }
        await transport.waitUntilFirstStartBegins()
        await feature.receive(.statusChanged(.localNetworkPermissionDenied))

        let retry = Task { await feature.send(.toggle) }
        await retry.value
        await transport.releaseFirstFailure()
        await firstAttempt.value

        guard case .on(let endpoint, _, _, _) = await feature.state() else {
            Issue.record("Expected the successful retry to remain authoritative")
            return
        }
        #expect(endpoint.port == 8_123)
        #expect(await sharing.isEnabled())
        #expect(await transport.startCount() == 2)
    }
}
