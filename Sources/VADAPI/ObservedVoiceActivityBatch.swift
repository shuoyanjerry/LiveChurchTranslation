/// Production lifecycle events paired with passive native-pause observations.
package struct ObservedVoiceActivityBatch: Sendable, Equatable {
    package let voiceEvents: [VoiceActivityEvent]
    package let pauseEvents: [CandidatePauseTraceEvent]

    package init(
        voiceEvents: [VoiceActivityEvent] = [],
        pauseEvents: [CandidatePauseTraceEvent] = []
    ) {
        self.voiceEvents = voiceEvents
        self.pauseEvents = pauseEvents
    }
}
