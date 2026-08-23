/// A replaceable, frame-level speech decision boundary.
///
/// The enclosing `VoiceActivityDetector` owns a classifier and calls it from
/// one actor. Implementations may therefore keep streaming state, but must not
/// be shared with another detector instance.
public protocol VoiceActivityClassifying: Sendable {
    /// Rejects a detector window that the classifier implementation cannot consume.
    func validateAnalysisWindow(sampleRate: Double, sampleCount: Int) throws

    /// Returns whether one validated mono analysis window contains speech.
    mutating func isSpeech(
        _ samples: [Float],
        whileSpeaking: Bool
    ) -> Bool

    /// Clears all classifier state between capture streams.
    mutating func reset()
}

extension VoiceActivityClassifying {
    public func validateAnalysisWindow(sampleRate _: Double, sampleCount _: Int) throws {}
}
