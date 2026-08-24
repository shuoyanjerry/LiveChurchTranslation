import AudioCaptureAPI
import DiagnosticsAPI
import Foundation

public protocol LiveSessionController: Sendable {
    func start(inputDeviceID: AudioInputID?) async
    func stop() async
    func prepareForShutdown() async
    func shutdown() async
    func currentSnapshot() async -> LiveSessionSnapshot
    func events() async -> AsyncStream<LiveSessionEvent>
}

extension LiveSessionController {
    public func prepareForShutdown() async {
        await stop()
    }

    public func shutdown() async {
        await prepareForShutdown()
    }
}
