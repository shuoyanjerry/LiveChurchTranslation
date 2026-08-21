struct RollingAudioBuffer {
    private let capacity: Int
    private let sampleRate: Double
    private(set) var samples: [Float] = []
    private(set) var startedAt: Duration?

    init(capacity: Int, sampleRate: Double) {
        self.capacity = capacity
        self.sampleRate = sampleRate
    }

    mutating func append(_ newSamples: [Float], at timestamp: Duration) {
        guard capacity > 0 else { return }
        if samples.isEmpty {
            startedAt = timestamp
        }
        samples.append(contentsOf: newSamples)
        trimOverflow()
    }

    mutating func removeAll() {
        samples.removeAll(keepingCapacity: true)
        startedAt = nil
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
    }
}
