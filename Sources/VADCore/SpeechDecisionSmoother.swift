import VADAPI

struct SpeechDecisionSmoother {
    private let capacity: Int
    private let requiredVotes: Int
    private var decisions: [Bool] = []

    init(configuration: VoiceActivityConfiguration) {
        capacity = configuration.decisionWindowCount
        requiredVotes = configuration.decisionSpeechVotes
    }

    mutating func append(_ decision: Bool) -> Bool {
        decisions.append(decision)
        if decisions.count > capacity {
            decisions.removeFirst(decisions.count - capacity)
        }
        return decisions.count >= requiredVotes
            && decisions.filter { $0 }.count >= requiredVotes
    }

    mutating func reset() {
        decisions.removeAll(keepingCapacity: true)
    }
}
