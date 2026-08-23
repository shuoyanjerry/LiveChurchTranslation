import UtteranceRecoveryAPI

struct UtteranceQueuePolicy: Sendable, Equatable {
    let maximumRecords: Int
    let maximumSamples: Int

    init(maximumRecords: Int, maximumSamples: Int) {
        precondition(maximumRecords > 0)
        precondition(maximumSamples > 0)
        self.maximumRecords = maximumRecords
        self.maximumSamples = maximumSamples
    }

    static let production = UtteranceQueuePolicy(
        maximumRecords: 32,
        maximumSamples: 16_000 * 60 * 5
    )
}

enum UtteranceQueueLimit: Sendable, Equatable {
    case recordCount
    case sampleCount
}

enum UtteranceQueueAdmission: Sendable, Equatable {
    case admitted
    case rejected(UtteranceQueueLimit)
}

struct PendingUtteranceQueue: Sendable {
    let policy: UtteranceQueuePolicy
    private var storage: [PendingUtteranceRecord?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0
    private(set) var sampleCount = 0

    init(policy: UtteranceQueuePolicy = .production) {
        self.policy = policy
        storage = Array(repeating: nil, count: policy.maximumRecords)
    }

    var isEmpty: Bool { count == 0 }

    mutating func enqueue(_ record: PendingUtteranceRecord) -> UtteranceQueueAdmission {
        guard count < policy.maximumRecords else {
            return .rejected(.recordCount)
        }
        let incomingSamples = record.segment.samples.count
        guard incomingSamples <= policy.maximumSamples - sampleCount else {
            return .rejected(.sampleCount)
        }
        storage[tail] = record
        tail = (tail + 1) % storage.count
        count += 1
        sampleCount += incomingSamples
        return .admitted
    }

    mutating func dequeue() -> PendingUtteranceRecord? {
        guard count > 0, let record = storage[head] else { return nil }
        storage[head] = nil
        head = (head + 1) % storage.count
        count -= 1
        sampleCount -= record.segment.samples.count
        return record
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: policy.maximumRecords)
        head = 0
        tail = 0
        count = 0
        sampleCount = 0
    }
}
