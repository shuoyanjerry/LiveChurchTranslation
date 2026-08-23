import VADAPI

extension ActiveSpeech {
    mutating func pauseResolution(
        reason: SpeechSegmentEndReason,
        observedAtSourceSample: Int64
    ) -> CandidatePauseTraceEvent? {
        guard let episodeNumber = endpointPause.resolveForSegmentEnd() else {
            return nil
        }
        return .resolved(
            CandidatePauseResolved(
                episode: episode(number: episodeNumber),
                observedAt: instant(at: observedAtSourceSample),
                reason: .segmentEnded(reason)
            )
        )
    }

    func makeTraceEvent(
        _ transition: EndpointPauseTransition
    ) -> CandidatePauseTraceEvent {
        switch transition {
        case .reached(let reach):
            return .reached(makeReachedEvent(reach))
        case .resumed(let episodeNumber, let observedAtSourceSample):
            return .resolved(
                CandidatePauseResolved(
                    episode: episode(number: episodeNumber),
                    observedAt: instant(at: observedAtSourceSample),
                    reason: .speechResumed
                )
            )
        }
    }

    private func makeReachedEvent(
        _ reach: EndpointPauseReach
    ) -> CandidatePauseReached {
        CandidatePauseReached(
            episode: episode(number: reach.episodeNumber),
            checkpoint: CandidatePauseCheckpoint(
                threshold: reach.threshold.checkpoint,
                thresholdSampleCount: Int64(reach.threshold.sampleCount)
            ),
            candidateEnd: instant(at: reach.candidateEndSourceSample),
            currentWindow: CandidatePauseObservationWindow(
                startSourceSample: reach.currentWindowStartSourceSample,
                end: instant(at: reach.currentWindowEndSourceSample)
            ),
            overshootSampleCount: reach.currentWindowEndSourceSample
                - reach.candidateEndSourceSample
        )
    }

    private func episode(number: UInt64) -> CandidatePauseEpisode {
        CandidatePauseEpisode(
            sequenceNumber: sequenceNumber,
            episodeNumber: number
        )
    }

    private func instant(at sourceSample: Int64) -> CandidatePauseTraceInstant {
        CandidatePauseTraceInstant(
            sourceSample: sourceSample,
            timestamp: timestamp(for: sourceSample)
        )
    }

    private func timestamp(for sourceSample: Int64) -> Duration {
        startedAt
            + AudioTiming.duration(
                sampleCount: sourceSample - startedAtSourceSample,
                sampleRate: sampleRate
            )
    }
}
