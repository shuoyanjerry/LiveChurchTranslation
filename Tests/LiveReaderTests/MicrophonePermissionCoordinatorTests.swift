import AudioCaptureAPI
import LiveReader
import Testing

@Suite @MainActor struct MicrophonePermissionCoordinatorTests {
    @Test func authorizedPermissionNeverPresentsGuidance() async {
        let client = PermissionClientFake(permission: .authorized)
        let coordinator = makeCoordinator(client: client)

        await coordinator.load()

        #expect(coordinator.guidance == nil)
        #expect(!coordinator.isPresented)
        #expect(await client.authorizationChecks() == 1)
    }

    @Test func undeterminedPermissionWaitsForUserActionBeforeRequesting() async {
        let client = PermissionClientFake(
            permission: .notDetermined,
            requestResult: .authorized
        )
        let coordinator = makeCoordinator(client: client)

        await coordinator.load()
        #expect(coordinator.guidance == .notDetermined)
        #expect(coordinator.isPresented)
        #expect(await client.permissionRequests() == 0)

        await coordinator.requestAccess()
        #expect(await client.permissionRequests() == 1)
        #expect(coordinator.guidance == nil)
        #expect(!coordinator.isPresented)
    }

    @Test(arguments: [AudioCapturePermission.denied, .restricted])
    func deniedAndRestrictedPermissionsLinkToSystemSettings(
        permission: AudioCapturePermission
    ) async {
        let opener = SettingsOpenerFake()
        let coordinator = makeCoordinator(
            client: PermissionClientFake(permission: permission),
            opener: opener
        )

        await coordinator.load()
        coordinator.openSystemSettings()

        #expect(coordinator.isPresented)
        #expect(coordinator.guidance == expectedGuidance(for: permission))
        #expect(opener.openCount == 1)
    }

    @Test func refreshHidesGuidanceImmediatelyAfterPermissionChanges() async {
        let client = PermissionClientFake(permission: .denied)
        let coordinator = makeCoordinator(client: client)
        await coordinator.load()
        #expect(coordinator.isPresented)

        await client.setPermission(.authorized)
        await coordinator.refresh()

        #expect(coordinator.guidance == nil)
        #expect(!coordinator.isPresented)
    }

    @Test func deferredGuidanceStaysQuietDuringCurrentLaunch() async {
        let client = PermissionClientFake(permission: .denied)
        let coordinator = makeCoordinator(client: client)
        await coordinator.load()

        coordinator.deferGuidance()
        await coordinator.refresh()

        #expect(coordinator.guidance == .denied)
        #expect(!coordinator.isPresented)
    }

    private func makeCoordinator(
        client: PermissionClientFake,
        opener: SettingsOpenerFake = SettingsOpenerFake(),
        requestTimeout: Duration = .seconds(20)
    ) -> MicrophonePermissionCoordinator {
        MicrophonePermissionCoordinator(
            permissionClient: client,
            settingsOpener: opener,
            requestTimeout: requestTimeout
        )
    }

    private func expectedGuidance(
        for permission: AudioCapturePermission
    ) -> MicrophonePermissionGuidance? {
        switch permission {
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        case .authorized: nil
        }
    }
}
