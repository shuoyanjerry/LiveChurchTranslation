import DiagnosticsAPI
import Foundation
import VADAPI

protocol SentenceVisibilityClock: Sendable {
    func now() -> Duration
}

struct ContinuousSentenceVisibilityClock: SentenceVisibilityClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() {
        origin = clock.now
    }

    func now() -> Duration {
        origin.duration(to: clock.now)
    }
}

struct SentenceAudioTimelineAnchor: Sendable {
    let audioTimestamp: Duration
    let monotonicTimestamp: Duration

    func monotonicTime(for audioTimestamp: Duration) -> Duration {
        monotonicTimestamp + audioTimestamp - self.audioTimestamp
    }
}

enum SentenceRealtimePolicy {
    static let tailToVisibleBudget = Duration.seconds(3)

    static func maximumAcousticWait(
        configuration: VoiceActivityConfiguration = .sermon
    ) -> Duration {
        configuration.preferredMaximumSegment + configuration.maximumBoundaryGrace
    }

    static func diagnostic(
        sourceSegmentSequence: UInt64,
        presentationSequence: Int,
        sentenceTail: Duration,
        tailObservedAt: Duration,
        visibleAt: Duration
    ) -> DiagnosticEvent {
        let latency = visibleAt - tailObservedAt
        let mappingIsValid = tailObservedAt >= .zero && visibleAt >= tailObservedAt
        let slaIsMet = mappingIsValid && latency <= tailToVisibleBudget
        return DiagnosticEvent(
            severity: slaIsMet ? .info : .warning,
            component: "SentenceVisibility",
            message: diagnosticMessage(mappingIsValid: mappingIsValid, slaIsMet: slaIsMet),
            measurements: [
                "source_segment_sequence": Double(sourceSegmentSequence),
                "presentation_sequence": Double(presentationSequence),
                "sentence_tail_audio_ms": sentenceTail.milliseconds,
                "tail_to_visible_ms": latency.milliseconds,
                "budget_ms": tailToVisibleBudget.milliseconds,
                "clock_mapping_valid": mappingIsValid ? 1 : 0,
                "sla_met": slaIsMet ? 1 : 0,
            ]
        )
    }

    private static func diagnosticMessage(mappingIsValid: Bool, slaIsMet: Bool) -> String {
        if !mappingIsValid { return "Sentence visibility clock mapping was invalid" }
        if slaIsMet { return "Sentence translation became visible" }
        return "Sentence translation missed the realtime visibility budget"
    }
}

extension Duration {
    fileprivate var milliseconds: Double {
        let parts = components
        return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
    }
}
