import VADAPI

struct ActiveSpeechSeed {
    let sequenceNumber: UInt64
    let samples: [Float]
    let startedAt: Duration
    let startedAtSourceSample: Int64
    let voicedSampleCount: Int
    let isConfirmedContinuation: Bool
}

struct ActiveSpeech {
    let sequenceNumber: UInt64
    let startedAt: Duration
    let startedAtSourceSample: Int64
    let isConfirmedContinuation: Bool
    let sampleRate: Double
    private(set) var samples: [Float]
    private(set) var rawTrailingSilenceSampleCount = 0
    private(set) var voicedSampleCount: Int
    var endpointPause: EndpointPauseTracker

    var endpointPauseSampleCount: Int {
        endpointPause.silenceSampleCount
    }

    var endpointPauseStartedAtSampleCount: Int? {
        endpointPause.startedAtSampleCount
    }

    init(seed: ActiveSpeechSeed, thresholds: SpeechSegmentationThresholds) {
        sequenceNumber = seed.sequenceNumber
        samples = seed.samples
        startedAt = seed.startedAt
        startedAtSourceSample = seed.startedAtSourceSample
        voicedSampleCount = seed.voicedSampleCount
        isConfirmedContinuation = seed.isConfirmedContinuation
        sampleRate = thresholds.sampleRate
        endpointPause = EndpointPauseTracker(
            thresholds: thresholds.candidatePauseThresholds
        )
    }

    mutating func append(
        _ newSamples: [Float],
        sourceSampleStart: Int64,
        rawSpeech: Bool,
        traceEligible: Bool
    ) -> [CandidatePauseTraceEvent] {
        let precedingSampleCount = samples.count
        precondition(
            sourceSampleStart == startedAtSourceSample + Int64(precedingSampleCount)
        )
        samples.append(contentsOf: newSamples)
        rawTrailingSilenceSampleCount =
            rawSpeech
            ? 0
            : rawTrailingSilenceSampleCount + newSamples.count
        let transitions = endpointPause.observe(
            rawSpeech: rawSpeech,
            sampleCount: newSamples.count,
            precedingSampleCount: precedingSampleCount,
            sourceSampleStart: sourceSampleStart,
            traceEligible: traceEligible
        )
        if rawSpeech {
            voicedSampleCount += newSamples.count
        }
        return transitions.map(makeTraceEvent)
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
