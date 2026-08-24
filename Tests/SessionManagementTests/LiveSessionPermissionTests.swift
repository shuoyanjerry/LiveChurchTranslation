import SessionManagementAPI
import Testing

@Suite struct LiveSessionPermissionTests {
    @Test func cancelledStartDoesNotCreateASession() async {
        let harness = SessionTestHarness()
        let startTask = Task {
            try? await Task.sleep(for: .seconds(10))
            await harness.coordinator.start(inputDeviceID: nil)
        }
        startTask.cancel()
        await startTask.value

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.sessionID == nil)
        #expect(snapshot.phase == .idle)
        #expect((await harness.downloader.requestedDescriptors()).isEmpty)
    }

    @Test func stopWhilePermissionPromptIsPendingReturnsToIdle() async throws {
        let harness = SessionTestHarness(holdsPermissionRequest: true)
        let startTask = Task { await harness.coordinator.start(inputDeviceID: nil) }
        try await waitForPermissionRequest(harness)

        #expect((await harness.coordinator.currentSnapshot()).phase == .requestingPermission)
        await harness.coordinator.stop()
        let stopped = await harness.coordinator.currentSnapshot()
        #expect(stopped.phase == .idle)
        #expect(stopped.finalizationOutcome == .cancelledBeforeCapture)
        #expect((await harness.downloader.requestedDescriptors()).isEmpty)

        await harness.capture.completePermissionRequest()
        await startTask.value
        #expect((await harness.coordinator.currentSnapshot()).phase == .idle)
    }

    private func waitForPermissionRequest(_ harness: SessionTestHarness) async throws {
        for _ in 0..<100 {
            if await harness.capture.permissionRequestIsPending() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for the permission request")
    }
}
