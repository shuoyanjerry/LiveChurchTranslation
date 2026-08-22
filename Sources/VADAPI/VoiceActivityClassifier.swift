/// A replaceable, frame-level speech decision boundary.
///
/// The enclosing `VoiceActivityDetector` owns a classifier and calls it from
/// one actor. Implementations may therefore keep streaming state, but must not
/// be shared with another detector instance.
public protocol VoiceActivityClassifying: Sendable {
    /// Returns whether one validated mono analysis window contains speech.
    mutating func isSpeech(
        _ samples: [Float],
        whileSpeaking: Bool
    ) -> Bool

    /// Clears all classifier state between capture streams.
    mutating func reset()
}
