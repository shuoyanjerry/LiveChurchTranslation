import AudioProcessingAPI
import VADAPI

struct VoiceActivityStateMachine {
    private let configuration: VoiceActivityConfiguration
    private let windowSampleCount: Int
    private var segmenter: SpeechWindowSegmenter
    private var analysisSamples: [Float] = []
    private var nextAnalysisTimestamp: Duration?
    private(set) var lastFrameTimestamp: Duration?

    init(
        configuration: VoiceActivityConfiguration,
        classifier: any VoiceActivityClassifying
    ) {
        self.configuration = configuration
        windowSampleCount = AudioTiming.sampleCount(
            for: configuration.analysisWindow,
            sampleRate: configuration.requiredSampleRate
        )
        segmenter = SpeechWindowSegmenter(
            configuration: configuration,
            classifier: classifier
        )
    }

    mutating func process(_ frame: ProcessedAudioFrame) -> [VoiceActivityEvent] {
        lastFrameTimestamp = frame.timestamp
        guard !frame.samples.isEmpty else { return [] }
        if nextAnalysisTimestamp == nil {
            nextAnalysisTimestamp = frame.timestamp
        }
        analysisSamples.append(contentsOf: frame.samples)
        return consumeCompleteWindows()
    }

    mutating func flush() -> [VoiceActivityEvent] {
        var events: [VoiceActivityEvent] = []
        if !analysisSamples.isEmpty, let timestamp = nextAnalysisTimestamp {
            analysisSamples.append(
                contentsOf: repeatElement(
                    0,
                    count: windowSampleCount - analysisSamples.count
                )
            )
            events += segmenter.consume(analysisSamples, at: timestamp)
        }
        events += segmenter.flush()
        clearStreamState(resetSequence: false)
        return events
    }

    mutating func reset() {
        clearStreamState(resetSequence: true)
    }

    private mutating func consumeCompleteWindows() -> [VoiceActivityEvent] {
        var events: [VoiceActivityEvent] = []
        while analysisSamples.count >= windowSampleCount {
            let window = Array(analysisSamples.prefix(windowSampleCount))
            analysisSamples.removeFirst(windowSampleCount)
            guard let timestamp = nextAnalysisTimestamp else { break }
            events += segmenter.consume(window, at: timestamp)
            nextAnalysisTimestamp =
                timestamp
                + AudioTiming.duration(
                    sampleCount: window.count,
                    sampleRate: configuration.requiredSampleRate
                )
        }
        return events
    }

    private mutating func clearStreamState(resetSequence: Bool) {
        analysisSamples.removeAll(keepingCapacity: true)
        nextAnalysisTimestamp = nil
        lastFrameTimestamp = nil
        segmenter.reset(resetSequence: resetSequence)
    }
}
