import VADAPI

struct ActiveSpeech {
    let sequenceNumber: UInt64
    let startedAt: Duration
    private(set) var samples: [Float]
    private(set) var trailingSilenceSampleCount = 0

    init(sequenceNumber: UInt64, samples: [Float], startedAt: Duration) {
        self.sequenceNumber = sequenceNumber
        self.samples = samples
        self.startedAt = startedAt
    }

    mutating func append(_ newSamples: [Float], isSpeech: Bool) {
        samples.append(contentsOf: newSamples)
        trailingSilenceSampleCount =
            isSpeech
            ? 0
            : trailingSilenceSampleCount + newSamples.count
    }

    func segment(
        sampleRate: Double,
        reason: SpeechSegmentEndReason
    ) -> SpeechSegment {
        SpeechSegment(
            sequenceNumber: sequenceNumber,
            samples: samples,
            sampleRate: sampleRate,
            startedAt: startedAt,
            endedAt: startedAt
                + AudioTiming.duration(
                    sampleCount: samples.count,
                    sampleRate: sampleRate
                ),
            endReason: reason
        )
    }
}
