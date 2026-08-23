struct RollingAudioBuffer {
    private let capacity: Int
    private let sampleRate: Double
    private(set) var samples: [Float] = []
    private(set) var startedAt: Duration?
    private(set) var startedAtSourceSample: Int64?

    init(capacity: Int, sampleRate: Double) {
        self.capacity = capacity
        self.sampleRate = sampleRate
    }

    mutating func append(
        _ newSamples: [Float],
        at timestamp: Duration,
        sourceSampleStart: Int64
    ) {
        guard capacity > 0, !newSamples.isEmpty else { return }
        if samples.isEmpty {
            startedAt = timestamp
            startedAtSourceSample = sourceSampleStart
        } else if let startedAtSourceSample {
            precondition(
                sourceSampleStart == startedAtSourceSample + Int64(samples.count)
            )
        }
        samples.append(contentsOf: newSamples)
        trimOverflow()
    }

    mutating func removeAll() {
        samples.removeAll(keepingCapacity: true)
        startedAt = nil
        startedAtSourceSample = nil
    }

    private mutating func trimOverflow() {
        let overflow = samples.count - capacity
        guard overflow > 0 else { return }
        samples.removeFirst(overflow)
        if let startedAt {
            self.startedAt =
                startedAt
                + AudioTiming.duration(
                    sampleCount: overflow,
                    sampleRate: sampleRate
                )
        }
        if let startedAtSourceSample {
            self.startedAtSourceSample = startedAtSourceSample + Int64(overflow)
        }
    }
}
