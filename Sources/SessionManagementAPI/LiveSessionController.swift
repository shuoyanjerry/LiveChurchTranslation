import AudioCaptureAPI
import DiagnosticsAPI
import Foundation

public protocol LiveSessionController: Sendable {
    func start(inputDeviceID: AudioInputID?) async
    func stop() async
    func currentSnapshot() async -> LiveSessionSnapshot
    func events() async -> AsyncStream<LiveSessionEvent>
}
