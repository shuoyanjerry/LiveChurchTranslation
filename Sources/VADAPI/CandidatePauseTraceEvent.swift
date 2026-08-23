/// Fixed shadow-observation checkpoints within a native endpoint pause.
package enum CandidatePauseThreshold: Int, Sendable, Equatable, CaseIterable {
    case milliseconds250 = 250
    case milliseconds300 = 300
    case milliseconds400 = 400

    package var duration: Duration {
        .milliseconds(rawValue)
    }
}

package struct CandidatePauseEpisode: Sendable, Equatable {
    package let sequenceNumber: UInt64
    package let episodeNumber: UInt64

    package init(sequenceNumber: UInt64, episodeNumber: UInt64) {
        self.sequenceNumber = sequenceNumber
        self.episodeNumber = episodeNumber
    }
}

package struct CandidatePauseCheckpoint: Sendable, Equatable {
    package let threshold: CandidatePauseThreshold
    package let thresholdSampleCount: Int64

    package init(
        threshold: CandidatePauseThreshold,
        thresholdSampleCount: Int64
    ) {
        self.threshold = threshold
        self.thresholdSampleCount = thresholdSampleCount
    }
}

package struct CandidatePauseTraceInstant: Sendable, Equatable {
    package let sourceSample: Int64
    package let timestamp: Duration

    package init(sourceSample: Int64, timestamp: Duration) {
        self.sourceSample = sourceSample
        self.timestamp = timestamp
    }
}

package struct CandidatePauseObservationWindow: Sendable, Equatable {
    package let startSourceSample: Int64
    package let end: CandidatePauseTraceInstant

    package init(
        startSourceSample: Int64,
        end: CandidatePauseTraceInstant
    ) {
        self.startSourceSample = startSourceSample
        self.end = end
    }
}

/// Evidence captured when a native endpoint pause crosses one checkpoint.
package struct CandidatePauseReached: Sendable, Equatable {
    package let episode: CandidatePauseEpisode
    package let checkpoint: CandidatePauseCheckpoint
    package let candidateEnd: CandidatePauseTraceInstant
    package let currentWindow: CandidatePauseObservationWindow
    package let overshootSampleCount: Int64

    package init(
        episode: CandidatePauseEpisode,
        checkpoint: CandidatePauseCheckpoint,
        candidateEnd: CandidatePauseTraceInstant,
        currentWindow: CandidatePauseObservationWindow,
        overshootSampleCount: Int64
    ) {
        self.episode = episode
        self.checkpoint = checkpoint
        self.candidateEnd = candidateEnd
        self.currentWindow = currentWindow
        self.overshootSampleCount = overshootSampleCount
    }
}

/// Why an observed candidate-pause episode stopped being pending.
package enum CandidatePauseResolutionReason: Sendable, Equatable {
    case speechResumed
    case segmentEnded(SpeechSegmentEndReason)
}

/// Evidence that closes one independently numbered candidate-pause episode.
package struct CandidatePauseResolved: Sendable, Equatable {
    package let episode: CandidatePauseEpisode
    package let observedAt: CandidatePauseTraceInstant
    package let reason: CandidatePauseResolutionReason

    package init(
        episode: CandidatePauseEpisode,
        observedAt: CandidatePauseTraceInstant,
        reason: CandidatePauseResolutionReason
    ) {
        self.episode = episode
        self.observedAt = observedAt
        self.reason = reason
    }
}

/// Package-scoped shadow evidence; it never participates in boundary decisions.
package enum CandidatePauseTraceEvent: Sendable, Equatable {
    case reached(CandidatePauseReached)
    case resolved(CandidatePauseResolved)
}
