import AudioCaptureAPI

/// Converts capture-device frames into one continuous mono stream.
///
/// Conformers may keep resampling state, so calls are asynchronous and must be
/// serialized by the implementation. `reset()` starts a new stream boundary.
public protocol AudioProcessor: Sendable {
    func process(_ frame: AudioFrame) async throws -> ProcessedAudioFrame
    func reset() async
}
