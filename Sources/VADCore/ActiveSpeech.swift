import VADAPI

struct ActiveSpeech {
    let sequenceNumber: UInt64
    let startedAt: Duration
    private(set) var samples: [Float]
    private(set) var rawTrailingSilenceSampleCount = 0
    private(set) var voicedSampleCount: Int
    private var endpointPause = EndpointPauseTracker()

    var endpointPauseSampleCount: Int {
        endpointPause.silenceSampleCount
    }

    var endpointPauseStartedAtSampleCount: Int? {
        endpointPause.startedAtSampleCount
    }

    init(
        sequenceNumber: UInt64,
        samples: [Float],
        startedAt: Duration,
        voicedSampleCount: Int
    ) {
        self.sequenceNumber = sequenceNumber
        self.samples = samples
        self.startedAt = startedAt
        self.voicedSampleCount = voicedSampleCount
    }

    mutating func append(_ newSamples: [Float], rawSpeech: Bool) {
        let precedingSampleCount = samples.count
        samples.append(contentsOf: newSamples)
        rawTrailingSilenceSampleCount =
            rawSpeech
            ? 0
            : rawTrailingSilenceSampleCount + newSamples.count
        endpointPause.observe(
            rawSpeech: rawSpeech,
            sampleCount: newSamples.count,
            precedingSampleCount: precedingSampleCount
        )
        if rawSpeech {
            voicedSampleCount += newSamples.count
        }
    }

    func segment(
        sampleRate: Double,
        reason: SpeechSegmentEndReason,
        trailingSamplesToKeep: Int
    ) -> SpeechSegment {
        let removableSilence = max(
            0,
            rawTrailingSilenceSampleCount - trailingSamplesToKeep
        )
        let retainedSamples = Array(samples.dropLast(removableSilence))
        return SpeechSegment(
            sequenceNumber: sequenceNumber,
            samples: retainedSamples,
            sampleRate: sampleRate,
            startedAt: startedAt,
            endedAt: startedAt
                + AudioTiming.duration(
                    sampleCount: retainedSamples.count,
                    sampleRate: sampleRate
                ),
            endReason: reason
        )
    }
}
