import AudioProcessingAPI

/// Segments a continuous mono stream into bounded speech utterances.
public protocol VoiceActivityDetector: Sendable {
    func process(_ frame: ProcessedAudioFrame) async throws -> [VoiceActivityEvent]

    /// Closes active speech when a capture stream ends normally.
    func flush() async -> [VoiceActivityEvent]

    /// Discards all buffered samples and adaptive state.
    func reset() async
}
