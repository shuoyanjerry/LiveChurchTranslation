/// An immutable block of captured PCM audio.
///
/// Samples are normalized `Float` values in frame-major, interleaved order.
/// A mono frame therefore contains one sample and a stereo frame contains two.
public struct AudioFrame: Equatable, Sendable {
    public let samples: [Float]
    public let sampleRate: Double
    public let channelCount: Int
    public let timestamp: Duration

    public init(
        samples: [Float],
        sampleRate: Double,
        channelCount: Int,
        timestamp: Duration
    ) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.timestamp = timestamp
    }

    /// The number of complete sample frames represented by this value.
    public var frameCount: Int {
        guard channelCount > 0 else { return 0 }
        return samples.count / channelCount
    }
}
