import VADAPI

struct SpeechStartPublication {
    private let minimumVoicedSampleCount: Int
    private(set) var nextSequenceNumber: UInt64 = 1
    private var hasPublishedStart = false

    var hasPublishedSpeech: Bool {
        hasPublishedStart
    }

    init(minimumVoicedSampleCount: Int) {
        self.minimumVoicedSampleCount = minimumVoicedSampleCount
    }

    mutating func eventsIfConfirmed(for speech: ActiveSpeech) -> [VoiceActivityEvent] {
        guard !hasPublishedStart,
            speech.isConfirmedContinuation
                || speech.voicedSampleCount >= minimumVoicedSampleCount
        else { return [] }
        hasPublishedStart = true
        nextSequenceNumber += 1
        return [
            .speechStarted(
                sequenceNumber: speech.sequenceNumber,
                at: speech.startedAt
            )
        ]
    }

    mutating func close() {
        hasPublishedStart = false
    }

    mutating func reset(resetSequence: Bool) {
        close()
        if resetSequence {
            nextSequenceNumber = 1
        }
    }
}
