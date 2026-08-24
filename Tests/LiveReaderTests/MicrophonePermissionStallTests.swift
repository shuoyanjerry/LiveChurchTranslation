import AudioCaptureAPI
import LiveReader
import Testing

@Suite @MainActor struct MicrophonePermissionStallTests {
    @Test func stalledRequestUsesObservedSystemDecision() async {
        let client = PermissionClientFake(
            permission: .notDetermined,
            requestResult: .authorized,
            requestDelay: .seconds(5)
        )
        let coordinator = makeCoordinator(
            client: client,
            requestTimeout: .milliseconds(20)
        )
        await coordinator.load()
        await client.setPermission(.authorized)

        await coordinator.requestAccess()

        #expect(await client.permissionRequests() == 1)
        #expect(!coordinator.isRequesting)
        #expect(coordinator.guidance == nil)
        #expect(!coordinator.isPresented)
    }

    @Test func stalledUndeterminedRequestStopsShowingBusyState() async {
        let client = PermissionClientFake(
            permission: .notDetermined,
            requestDelay: .seconds(5)
        )
        let coordinator = makeCoordinator(
            client: client,
            requestTimeout: .milliseconds(20)
        )
        await coordinator.load()

        await coordinator.requestAccess()

        #expect(!coordinator.isRequesting)
        #expect(coordinator.guidance == .notDetermined)
        #expect(coordinator.isPresented)
    }

    @Test func refreshReconcilesPermissionWhileRequestCallbackIsStalled() async {
        let client = PermissionClientFake(
            permission: .notDetermined,
            requestResult: .authorized,
            requestDelay: .seconds(5)
        )
        let coordinator = makeCoordinator(client: client)
        await coordinator.load()
        let requestTask = Task { await coordinator.requestAccess() }
        for _ in 0..<100 {
            if await client.permissionRequests() == 1 { break }
            await Task.yield()
        }
        await client.setPermission(.authorized)

        await coordinator.refresh()

        #expect(!coordinator.isRequesting)
        #expect(coordinator.guidance == nil)
        #expect(!coordinator.isPresented)
        requestTask.cancel()
        await requestTask.value
    }

    private func makeCoordinator(
        client: PermissionClientFake,
        requestTimeout: Duration = .seconds(20)
    ) -> MicrophonePermissionCoordinator {
        MicrophonePermissionCoordinator(
            permissionClient: client,
            settingsOpener: SettingsOpenerFake(),
            requestTimeout: requestTimeout
        )
    }
}
