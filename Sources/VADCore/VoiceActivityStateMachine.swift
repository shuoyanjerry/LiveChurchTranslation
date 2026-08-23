import AudioProcessingAPI
import VADAPI

struct VoiceActivityStateMachine {
    private let configuration: VoiceActivityConfiguration
    private let windowSampleCount: Int
    private var segmenter: SpeechWindowSegmenter
    private var analysisSamples: [Float] = []
    private var nextAnalysisTimestamp: Duration?
    private var nextAnalysisSourceSample: Int64 = 0
    private(set) var lastFrameTimestamp: Duration?
    private(set) var expectedNextFrameTimestamp: Duration?

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

    mutating func process(_ frame: ProcessedAudioFrame) -> ObservedVoiceActivityBatch {
        lastFrameTimestamp = frame.timestamp
        expectedNextFrameTimestamp = frame.timestamp + frame.duration
        guard !frame.samples.isEmpty else { return ObservedVoiceActivityBatch() }
        if nextAnalysisTimestamp == nil {
            nextAnalysisTimestamp = frame.timestamp
        }
        analysisSamples.append(contentsOf: frame.samples)
        return consumeCompleteWindows()
    }

    mutating func flush() -> ObservedVoiceActivityBatch {
        var voiceEvents: [VoiceActivityEvent] = []
        var pauseEvents: [CandidatePauseTraceEvent] = []
        if !analysisSamples.isEmpty, let timestamp = nextAnalysisTimestamp {
            let validSampleCount = analysisSamples.count
            analysisSamples.append(
                contentsOf: repeatElement(
                    0,
                    count: windowSampleCount - analysisSamples.count
                )
            )
            let partial = segmenter.consume(
                analysisSamples,
                at: timestamp,
                sourceSampleStart: nextAnalysisSourceSample,
                validSampleCount: validSampleCount
            )
            voiceEvents += partial.voiceEvents
            pauseEvents += partial.pauseEvents
        }
        let flushed = segmenter.flush()
        voiceEvents += flushed.voiceEvents
        pauseEvents += flushed.pauseEvents
        clearStreamState(resetSequence: false)
        return ObservedVoiceActivityBatch(
            voiceEvents: voiceEvents,
            pauseEvents: pauseEvents
        )
    }

    mutating func reset() {
        clearStreamState(resetSequence: true)
    }

    private mutating func consumeCompleteWindows() -> ObservedVoiceActivityBatch {
        var voiceEvents: [VoiceActivityEvent] = []
        var pauseEvents: [CandidatePauseTraceEvent] = []
        while analysisSamples.count >= windowSampleCount {
            let window = Array(analysisSamples.prefix(windowSampleCount))
            analysisSamples.removeFirst(windowSampleCount)
            guard let timestamp = nextAnalysisTimestamp else { break }
            let observed = segmenter.consume(
                window,
                at: timestamp,
                sourceSampleStart: nextAnalysisSourceSample
            )
            voiceEvents += observed.voiceEvents
            pauseEvents += observed.pauseEvents
            nextAnalysisTimestamp =
                timestamp
                + AudioTiming.duration(
                    sampleCount: window.count,
                    sampleRate: configuration.requiredSampleRate
                )
            nextAnalysisSourceSample += Int64(window.count)
        }
        return ObservedVoiceActivityBatch(
            voiceEvents: voiceEvents,
            pauseEvents: pauseEvents
        )
    }

    private mutating func clearStreamState(resetSequence: Bool) {
        analysisSamples.removeAll(keepingCapacity: true)
        nextAnalysisTimestamp = nil
        nextAnalysisSourceSample = 0
        lastFrameTimestamp = nil
        expectedNextFrameTimestamp = nil
        segmenter.reset(resetSequence: resetSequence)
    }
}
