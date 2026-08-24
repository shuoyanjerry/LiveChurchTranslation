import Foundation
import Testing

@Suite("Live session application shutdown")
struct LiveSessionShutdownTests {
    @Test func shutdownReleasesIdleInferenceRuntimes() async throws {
        let harness = SessionTestHarness()
        try await harness.asr.loadModel(at: URL(fileURLWithPath: "/tmp/asr-model"))
        await harness.translator.loadModel(
            at: URL(fileURLWithPath: "/tmp/translation-model")
        )
        #expect(await harness.asr.isModelRuntimeReady())
        #expect(await harness.translator.isModelRuntimeReady())

        await harness.coordinator.stop()

        #expect(await harness.asr.isModelRuntimeReady())
        #expect(await harness.translator.isModelRuntimeReady())

        await harness.coordinator.shutdown()

        #expect(!(await harness.asr.isModelRuntimeReady()))
        #expect(!(await harness.translator.isModelRuntimeReady()))
    }

    @Test func shutdownFinalizesActiveSessionBeforeReleasingRuntimes() async {
        let harness = SessionTestHarness(holdsCaptureOpen: true)
        await harness.coordinator.start(inputDeviceID: nil)
        let active = await harness.coordinator.currentSnapshot()
        #expect(active.sessionID != nil)
        #expect(await harness.asr.isModelRuntimeReady())
        #expect(await harness.translator.isModelRuntimeReady())

        await harness.coordinator.shutdown()

        let finished = await harness.coordinator.currentSnapshot()
        #expect(finished.sessionID == nil)
        #expect(finished.phase == .idle)
        #expect(!(await harness.asr.isModelRuntimeReady()))
        #expect(!(await harness.translator.isModelRuntimeReady()))
    }

    @Test func shutdownPermanentlyRejectsQueuedAndFutureStarts() async {
        let harness = SessionTestHarness(holdsCaptureOpen: true)

        await harness.coordinator.shutdown()
        await harness.coordinator.start(inputDeviceID: nil)

        let snapshot = await harness.coordinator.currentSnapshot()
        #expect(snapshot.sessionID == nil)
        #expect(snapshot.phase == .idle)
        #expect((await harness.capture.capturedRequests()).isEmpty)
        #expect(await harness.asr.loadCount() == 0)
        #expect(await harness.translator.loadCount() == 0)
    }

    @Test func shutdownPreparationStopsAndFencesWithoutUnloadingRuntimes() async throws {
        let harness = SessionTestHarness(holdsCaptureOpen: true)
        try await harness.asr.loadModel(at: URL(fileURLWithPath: "/tmp/asr-model"))
        await harness.translator.loadModel(at: URL(fileURLWithPath: "/tmp/translation-model"))
        await harness.coordinator.start(inputDeviceID: nil)

        await harness.coordinator.prepareForShutdown()
        await harness.coordinator.start(inputDeviceID: nil)

        #expect((await harness.coordinator.currentSnapshot()).sessionID == nil)
        #expect(await harness.capture.capturedRequests().count == 1)
        #expect(await harness.asr.isModelRuntimeReady())
        #expect(await harness.translator.isModelRuntimeReady())
    }
}
