import AudioCaptureAPI
import Foundation
import RemoteControlSessionAdapter
import SessionManagementAPI
import SettingsAPI
import Testing

@Suite("Live session remote mutation adapter")
struct RemoteControlSessionAdapterTests {
    @Test("Remote Start uses the current Mac input and Stop forwards")
    func forwardsNarrowCommands() async throws {
        let controller = SessionControllerFake()
        let settings = SettingsFake(deviceID: "microphone-2")
        let adapter = LiveSessionRemoteMutationTarget(controller: controller, settings: settings)
        try await adapter.startRemoteSession()
        try await adapter.stopRemoteSession()
        #expect(await controller.startedInput()?.rawValue == "microphone-2")
        #expect(await controller.stopCount() == 1)
    }
}

private actor SessionControllerFake: LiveSessionController {
    private var input: AudioInputID?
    private var stops = 0
    private var active = false
    func start(inputDeviceID: AudioInputID?) {
        input = inputDeviceID
        active = true
    }
    func stop() {
        stops += 1
        active = false
    }
    func currentSnapshot() -> LiveSessionSnapshot {
        .init(
            sessionID: active ? UUID(uuidString: "00000000-0000-0000-0000-000000000001") : nil,
            phase: active ? .listening : .idle,
            transcript: [],
            modelStatus: nil,
            statusMessage: active ? "Listening" : "Ready"
        )
    }
    func events() -> AsyncStream<LiveSessionEvent> { AsyncStream { $0.finish() } }
    func startedInput() -> AudioInputID? { input }
    func stopCount() -> Int { stops }
}

private struct SettingsFake: SettingsStore {
    let deviceID: String?
    func load() -> AppSettings { AppSettings(selectedAudioDeviceID: deviceID) }
    func save(_ settings: AppSettings) {}
}
