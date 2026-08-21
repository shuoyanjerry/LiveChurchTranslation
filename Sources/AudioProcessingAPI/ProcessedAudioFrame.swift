/// A normalized, mono audio frame suitable for VAD and speech recognition.
///
/// Implementations of ``AudioProcessor`` guarantee a positive sample rate and
/// finite samples. The public initializer also supports deterministic fakes.
public struct ProcessedAudioFrame: Sendable, Equatable {
    public let samples: [Float]
    public let sampleRate: Double
    public let timestamp: Duration

    public init(
        samples: [Float],
        sampleRate: Double = 16_000,
        timestamp: Duration
    ) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }

    public var duration: Duration {
        guard sampleRate.isFinite, sampleRate > 0 else { return .zero }
        return .seconds(Double(samples.count) / sampleRate)
    }
}
