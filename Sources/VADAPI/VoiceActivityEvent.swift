/// Explicit state changes emitted by a voice activity detector.
public enum VoiceActivityEvent: Sendable, Equatable {
    /// Emitted after the voiced minimum or for accepted hard-cap continuation audio.
    case speechStarted(sequenceNumber: UInt64, at: Duration)

    case speechEnded(SpeechSegment)
}
