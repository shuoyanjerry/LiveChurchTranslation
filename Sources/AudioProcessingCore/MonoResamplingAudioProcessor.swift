import AudioCaptureAPI
import AudioProcessingAPI

/// Actor-isolated streaming downmixer and linear sample-rate converter.
public actor MonoResamplingAudioProcessor: AudioProcessor {
    private let configuration: AudioProcessingConfiguration
    private let downmixer = InterleavedDownmixer()
    private var resampler = StreamingLinearResampler()
    private var inputSampleRate: Double?
    private var nextOutputTimestamp: Duration?

    public init(
        configuration: AudioProcessingConfiguration = .speechRecognition
    ) throws {
        try AudioFrameValidator.validate(configuration)
        self.configuration = configuration
    }

    public func process(_ frame: AudioFrame) throws -> ProcessedAudioFrame {
        try AudioFrameValidator.validate(frame)
        guard !frame.samples.isEmpty else {
            return outputFrame(samples: [], timestamp: frame.timestamp)
        }

        prepareStream(for: frame)
        let mono = downmixer.mix(
            samples: frame.samples,
            channelCount: frame.channelCount,
            amplitudeLimit: configuration.amplitudeLimit
        )
        let output = resampler.convert(
            mono,
            sourceRate: frame.sampleRate,
            targetRate: configuration.targetSampleRate
        )
        let timestamp = nextOutputTimestamp ?? frame.timestamp
        nextOutputTimestamp = timestamp + outputDuration(sampleCount: output.count)
        return outputFrame(samples: output, timestamp: timestamp)
    }

    public func reset() {
        resampler.reset()
        inputSampleRate = nil
        nextOutputTimestamp = nil
    }

    private func prepareStream(for frame: AudioFrame) {
        guard inputSampleRate != frame.sampleRate else { return }
        resampler.reset()
        inputSampleRate = frame.sampleRate
        nextOutputTimestamp = frame.timestamp
    }

    private func outputDuration(sampleCount: Int) -> Duration {
        .seconds(Double(sampleCount) / configuration.targetSampleRate)
    }

    private func outputFrame(
        samples: [Float],
        timestamp: Duration
    ) -> ProcessedAudioFrame {
        ProcessedAudioFrame(
            samples: samples,
            sampleRate: configuration.targetSampleRate,
            timestamp: timestamp
        )
    }
}
