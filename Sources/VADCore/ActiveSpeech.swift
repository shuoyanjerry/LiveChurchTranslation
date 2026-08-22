import VADAPI

struct ActiveSpeech {
    let sequenceNumber: UInt64
    let startedAt: Duration
    private(set) var samples: [Float]
    private(set) var trailingSilenceSampleCount = 0
    private(set) var voicedSampleCount: Int

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

    mutating func append(_ newSamples: [Float], isSpeech: Bool) {
        samples.append(contentsOf: newSamples)
        trailingSilenceSampleCount =
            isSpeech
            ? 0
            : trailingSilenceSampleCount + newSamples.count
        if isSpeech {
            voicedSampleCount += newSamples.count
        }
    }

    func segment(
        sampleRate: Double,
        reason: SpeechSegmentEndReason,
        trailingSamplesToKeep: Int
    ) -> SpeechSegment {
        let removableSilence = max(0, trailingSilenceSampleCount - trailingSamplesToKeep)
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
