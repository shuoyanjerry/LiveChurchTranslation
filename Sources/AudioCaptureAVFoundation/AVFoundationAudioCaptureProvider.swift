import AVFoundation
import AudioCaptureAPI

/// AVFoundation/Core Audio implementation of the audio-capture boundary.
public actor AVFoundationAudioCaptureProvider: AudioCaptureProvider {
    private typealias Stream = AsyncThrowingStream<AudioFrame, any Error>

    private var engine: AVAudioEngine?
    private var continuation: Stream.Continuation?
    private var hasInstalledTap = false

    public init() {}

    public func authorizationStatus() -> AudioCapturePermission {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied: .denied
        case .authorized: .authorized
        @unknown default: .denied
        }
    }

    public func requestPermission() async -> AudioCapturePermission {
        if authorizationStatus() != .notDetermined {
            return authorizationStatus()
        }
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return authorizationStatus()
    }

    public func availableInputs() throws -> [AudioInputDevice] {
        try CoreAudioInputDeviceCatalog.devices().map(\.metadata)
    }

    public func startCapture(
        request: AudioCaptureRequest
    ) async throws -> AsyncThrowingStream<AudioFrame, any Error> {
        guard engine == nil else { throw AudioCaptureError.captureAlreadyRunning }
        guard authorizationStatus() == .authorized else {
            throw AudioCaptureError.permissionDenied
        }
        let prepared = try AudioEngineFactory.prepare(request: request)
        let (stream, streamContinuation) = makeStream()
        AudioCaptureTap.install(
            on: prepared.inputNode,
            capacity: prepared.capacity,
            into: streamContinuation
        )
        try AudioEngineFactory.start(prepared, stream: streamContinuation)
        engine = prepared.engine
        continuation = streamContinuation
        hasInstalledTap = true
        return stream
    }

    public func stopCapture() {
        if hasInstalledTap, let engine {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine?.stop()
        continuation?.finish()
        continuation = nil
        engine = nil
        hasInstalledTap = false
    }

    private func makeStream() -> (stream: Stream, continuation: Stream.Continuation) {
        let pair = Stream.makeStream(bufferingPolicy: .bufferingOldest(64))
        pair.continuation.onTermination = { [weak self] _ in
            Task { [weak self] in await self?.stopCapture() }
        }
        return pair
    }

}
