/// Explicit state changes emitted by a voice activity detector.
public enum VoiceActivityEvent: Sendable, Equatable {
    /// Emitted only after the configured minimum voiced duration is confirmed.
    case speechStarted(sequenceNumber: UInt64, at: Duration)

    case speechEnded(SpeechSegment)
}
