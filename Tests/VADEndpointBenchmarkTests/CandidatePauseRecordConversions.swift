import VADAPI

extension CandidatePauseReachedRecord {
    init(_ value: CandidatePauseReached) {
        thresholdMilliseconds = value.checkpoint.threshold.rawValue
        thresholdSampleCount = value.checkpoint.thresholdSampleCount
        candidateEndSourceSample = value.candidateEnd.sourceSample
        candidateEndSeconds = value.candidateEnd.timestamp.secondsValue
        observationStartSourceSample = value.currentWindow.startSourceSample
        observationEndSourceSample = value.currentWindow.end.sourceSample
        observationEndSeconds = value.currentWindow.end.timestamp.secondsValue
        overshootSampleCount = value.overshootSampleCount
    }
}

extension CandidatePauseResolutionRecord {
    init(_ value: CandidatePauseResolved) {
        observedAtSourceSample = value.observedAt.sourceSample
        observedAtSeconds = value.observedAt.timestamp.secondsValue
        switch value.reason {
        case .speechResumed:
            kind = "speechResumed"
            segmentEndReason = nil
        case .segmentEnded(let reason):
            kind = "segmentEnded"
            segmentEndReason = candidatePauseReasonName(reason)
        }
    }
}

extension CandidatePauseFinalizedBoundary {
    init(_ value: VADBoundaryRecord) {
        sequenceNumber = value.sequenceNumber
        startSample = value.startSample
        endSample = value.endSample
        validSampleCount = value.validSampleCount
        pcmSHA256 = value.pcmSHA256
        startedAtSeconds = value.startedAtSeconds
        endedAtSeconds = value.endedAtSeconds
        reason = value.reason
    }
}

func candidatePauseReasonName(_ reason: SpeechSegmentEndReason) -> String {
    switch reason {
    case .trailingSilence: "trailingSilence"
    case .softSilence: "softSilence"
    case .maximumBoundary: "maximumBoundary"
    case .maximumDuration: "maximumDuration"
    case .endOfStream: "endOfStream"
    }
}
