/// Replaceable boundary for enumerating and capturing audio inputs.
///
/// Implementations own their capture resources. At most one stream is active per
/// provider instance. Ending or cancelling the returned stream releases capture.
public protocol AudioCaptureProvider: Sendable {
    func authorizationStatus() async -> AudioCapturePermission
    func requestPermission() async -> AudioCapturePermission
    func availableInputs() async throws -> [AudioInputDevice]

    func startCapture(
        request: AudioCaptureRequest
    ) async throws -> AsyncThrowingStream<AudioFrame, any Error>

    func stopCapture() async
}
