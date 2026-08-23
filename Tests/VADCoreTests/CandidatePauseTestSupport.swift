import AudioProcessingAPI
import VADAPI
@testable import VADCore

enum CandidatePauseTestSupport {
    static func detector(
        preRoll: Duration = .milliseconds(20),
        minimumVoiced: Duration = .milliseconds(40),
        preferredMaximum: Duration = .seconds(15),
        maximumGrace: Duration = .milliseconds(1_500),
        trailingSilence: Duration = .milliseconds(650)
    ) throws -> CalibratedVoiceActivityDetector {
        let configuration = VoiceActivityConfiguration(
            analysisWindow: .milliseconds(20),
            preRoll: preRoll,
            speechStart: .milliseconds(20),
            trailingSilence: trailingSilence,
            shortUtterance: minimumVoiced,
            shortTrailingSilence: trailingSilence,
            softSplitSilence: .milliseconds(500),
            softSplitAfter: .seconds(9),
            preferredMaximumSegment: preferredMaximum,
            maximumBoundaryGrace: maximumGrace,
            postRoll: .milliseconds(280),
            minimumVoiced: minimumVoiced,
            decisionWindowCount: 1,
            decisionSpeechVotes: 1
        )
        return try CalibratedVoiceActivityDetector(
            classifier: FixedAmplitudeClassifier(),
            configuration: configuration
        )
    }

    static func observe(
        _ detector: CalibratedVoiceActivityDetector,
        amplitude: Float,
        milliseconds: Int,
        timestamp: Duration
    ) async throws -> ObservedVoiceActivityBatch {
        try await detector.processWithShadowEvidence(
            VADTestSupport.frame(
                amplitude: amplitude,
                milliseconds: milliseconds,
                timestamp: timestamp
            )
        )
    }

    static func reached(
        in events: [CandidatePauseTraceEvent]
    ) -> [CandidatePauseReached] {
        events.compactMap { event in
            guard case .reached(let value) = event else { return nil }
            return value
        }
    }

    static func resolved(
        in events: [CandidatePauseTraceEvent]
    ) -> [CandidatePauseResolved] {
        events.compactMap { event in
            guard case .resolved(let value) = event else { return nil }
            return value
        }
    }

    static func pauseLifecycle(
        _ detector: CalibratedVoiceActivityDetector
    ) async throws -> CandidatePauseLifecycleObservation {
        _ = try await observe(
            detector, amplitude: 0.1, milliseconds: 300, timestamp: .zero
        )
        let firstPause = try await observe(
            detector, amplitude: 0, milliseconds: 260, timestamp: .milliseconds(300)
        )
        let blip = try await observe(
            detector, amplitude: 0.1, milliseconds: 20, timestamp: .milliseconds(560)
        )
        let continuedPause = try await observe(
            detector, amplitude: 0, milliseconds: 40, timestamp: .milliseconds(580)
        )
        let resumed = try await observe(
            detector, amplitude: 0.1, milliseconds: 40, timestamp: .milliseconds(620)
        )
        let secondPause = try await observe(
            detector, amplitude: 0, milliseconds: 260, timestamp: .milliseconds(660)
        )
        return CandidatePauseLifecycleObservation(
            firstPause: firstPause,
            blip: blip,
            continuedPause: continuedPause,
            resumed: resumed,
            secondPause: secondPause
        )
    }

    static func voiceSignature(
        _ events: [VoiceActivityEvent]
    ) -> [VoiceEventSignature] {
        events.map { event in
            switch event {
            case .speechStarted(let sequenceNumber, let timestamp):
                return .started(sequenceNumber, timestamp)
            case .speechEnded(let segment):
                return .ended(
                    segment.sequenceNumber,
                    segment.samples.count,
                    segment.startedAt,
                    segment.endedAt,
                    segment.endReason
                )
            }
        }
    }
}

struct CandidatePauseLifecycleObservation {
    let firstPause: ObservedVoiceActivityBatch
    let blip: ObservedVoiceActivityBatch
    let continuedPause: ObservedVoiceActivityBatch
    let resumed: ObservedVoiceActivityBatch
    let secondPause: ObservedVoiceActivityBatch
}

enum VoiceEventSignature: Equatable {
    case started(UInt64, Duration)
    case ended(UInt64, Int, Duration, Duration, SpeechSegmentEndReason)
}

private struct FixedAmplitudeClassifier: VoiceActivityClassifying {
    mutating func isSpeech(_ samples: [Float], whileSpeaking _: Bool) -> Bool {
        samples.contains { abs($0) >= 0.05 }
    }

    mutating func reset() {}
}
