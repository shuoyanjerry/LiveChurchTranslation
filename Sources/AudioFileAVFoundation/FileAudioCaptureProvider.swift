import AudioCaptureAPI
import Foundation

public actor FileAudioCaptureProvider: AudioCaptureProvider {
    public nonisolated static let inputID = AudioInputID(rawValue: "selected-audio-file")
    public nonisolated let sourceURL: URL

    private struct ActiveCapture {
        let id: UUID
        let decoder: FileAudioDecoder
    }

    private var activeCapture: ActiveCapture?

    public init(url: URL) {
        sourceURL = url
    }

    public func authorizationStatus() -> AudioCapturePermission {
        .authorized
    }

    public func requestPermission() -> AudioCapturePermission {
        .authorized
    }

    public func availableInputs() -> [AudioInputDevice] {
        [
            AudioInputDevice(
                id: Self.inputID,
                name: sourceURL.lastPathComponent,
                isDefault: true
            )
        ]
    }

    public func startCapture(
        request: AudioCaptureRequest
    ) throws -> AsyncThrowingStream<AudioFrame, any Error> {
        guard activeCapture == nil else {
            throw AudioCaptureError.captureAlreadyRunning
        }
        if let requestedID = request.deviceID, requestedID != Self.inputID {
            throw AudioCaptureError.deviceNotFound(requestedID)
        }
        let seconds = request.bufferDuration.fileAudioSeconds
        guard seconds.isFinite, seconds > 0 else {
            throw AudioCaptureError.invalidConfiguration("Buffer duration must be positive.")
        }
        let decoder = try FileAudioDecoder.open(
            url: sourceURL,
            bufferSeconds: seconds
        )
        let captureID = UUID()
        activeCapture = ActiveCapture(id: captureID, decoder: decoder)
        let lifetime = FileAudioStreamLifetime { [weak self] in
            Task { [weak self] in await self?.cancelCapture(id: captureID) }
        }
        return AsyncThrowingStream(unfolding: { [weak self] in
            _ = lifetime
            do {
                let frame = try await decoder.nextFrame()
                if frame == nil { await self?.finishCapture(id: captureID) }
                return frame
            } catch {
                await self?.finishCapture(id: captureID)
                throw error
            }
        })
    }

    public func stopCapture() async {
        guard let capture = activeCapture else { return }
        activeCapture = nil
        await capture.decoder.cancel()
    }

    private func finishCapture(id: UUID) {
        guard activeCapture?.id == id else { return }
        activeCapture = nil
    }

    private func cancelCapture(id: UUID) async {
        guard let capture = activeCapture, capture.id == id else { return }
        activeCapture = nil
        await capture.decoder.cancel()
    }
}

private final class FileAudioStreamLifetime: @unchecked Sendable {
    private let onRelease: @Sendable () -> Void

    init(onRelease: @escaping @Sendable () -> Void) {
        self.onRelease = onRelease
    }

    deinit {
        onRelease()
    }
}

extension Duration {
    fileprivate var fileAudioSeconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
