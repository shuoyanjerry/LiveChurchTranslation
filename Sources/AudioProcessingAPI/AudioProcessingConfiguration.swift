/// Immutable settings for converting captured audio into an ASR-ready stream.
public struct AudioProcessingConfiguration: Sendable, Equatable {
    /// The sample rate expected by the downstream recognizer.
    public let targetSampleRate: Double

    /// The absolute output limit applied after channel mixing.
    public let amplitudeLimit: Float

    public init(
        targetSampleRate: Double = 16_000,
        amplitudeLimit: Float = 1
    ) {
        self.targetSampleRate = targetSampleRate
        self.amplitudeLimit = amplitudeLimit
    }

    /// Standard configuration for local speech-recognition models.
    public static let speechRecognition = AudioProcessingConfiguration()
}
