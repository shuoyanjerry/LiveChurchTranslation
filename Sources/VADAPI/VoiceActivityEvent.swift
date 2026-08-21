/// Explicit state changes emitted by a voice activity detector.
public enum VoiceActivityEvent: Sendable, Equatable {
    case speechStarted(sequenceNumber: UInt64, at: Duration)
    case speechEnded(SpeechSegment)
}
