import VADAPI

struct EndpointPauseThreshold {
    let checkpoint: CandidatePauseThreshold
    let sampleCount: Int
}

struct EndpointPauseReach {
    let episodeNumber: UInt64
    let threshold: EndpointPauseThreshold
    let candidateEndSourceSample: Int64
    let currentWindowStartSourceSample: Int64
    let currentWindowEndSourceSample: Int64
}

enum EndpointPauseTransition {
    case reached(EndpointPauseReach)
    case resumed(episodeNumber: UInt64, observedAtSourceSample: Int64)
}

struct EndpointPauseTracker {
    private let thresholds: [EndpointPauseThreshold]
    private(set) var silenceSampleCount = 0
    private(set) var startedAtSampleCount: Int?
    private var consecutiveSpeechFrameCount = 0
    private var currentEpisodeNumber: UInt64?
    private var currentEpisodeIsTraceable = false
    private var currentEpisodeHasReached = false
    private var nextEpisodeNumber: UInt64 = 1

    init(thresholds: [EndpointPauseThreshold]) {
        self.thresholds = thresholds
    }

    mutating func observe(
        rawSpeech: Bool,
        sampleCount: Int,
        precedingSampleCount: Int,
        sourceSampleStart: Int64,
        traceEligible: Bool
    ) -> [EndpointPauseTransition] {
        if rawSpeech {
            return observeSpeech(
                sampleCount: sampleCount,
                sourceSampleStart: sourceSampleStart
            )
        }
        return observeSilence(
            sampleCount: sampleCount,
            precedingSampleCount: precedingSampleCount,
            sourceSampleStart: sourceSampleStart,
            traceEligible: traceEligible
        )
    }

    mutating func resolveForSegmentEnd() -> UInt64? {
        guard currentEpisodeHasReached else { return nil }
        return currentEpisodeNumber
    }

    private mutating func observeSpeech(
        sampleCount: Int,
        sourceSampleStart: Int64
    ) -> [EndpointPauseTransition] {
        guard silenceSampleCount > 0 else { return [] }
        consecutiveSpeechFrameCount += 1
        guard consecutiveSpeechFrameCount >= 2 else { return [] }
        let episodeNumber = currentEpisodeHasReached ? currentEpisodeNumber : nil
        clearCurrentEpisode()
        guard let episodeNumber else { return [] }
        return [
            .resumed(
                episodeNumber: episodeNumber,
                observedAtSourceSample: sourceSampleStart + Int64(sampleCount)
            )
        ]
    }

    private mutating func observeSilence(
        sampleCount: Int,
        precedingSampleCount: Int,
        sourceSampleStart: Int64,
        traceEligible: Bool
    ) -> [EndpointPauseTransition] {
        beginEpisodeIfNeeded(
            precedingSampleCount: precedingSampleCount,
            traceEligible: traceEligible
        )
        consecutiveSpeechFrameCount = 0
        let previousSilenceSampleCount = silenceSampleCount
        silenceSampleCount += sampleCount
        guard currentEpisodeIsTraceable, let episodeNumber = currentEpisodeNumber else {
            return []
        }
        let windowEnd = sourceSampleStart + Int64(sampleCount)
        let reaches = thresholds.compactMap { threshold -> EndpointPauseTransition? in
            guard
                previousSilenceSampleCount < threshold.sampleCount,
                silenceSampleCount >= threshold.sampleCount
            else { return nil }
            let samplesNeeded = threshold.sampleCount - previousSilenceSampleCount
            return .reached(
                EndpointPauseReach(
                    episodeNumber: episodeNumber,
                    threshold: threshold,
                    candidateEndSourceSample: sourceSampleStart + Int64(samplesNeeded),
                    currentWindowStartSourceSample: sourceSampleStart,
                    currentWindowEndSourceSample: windowEnd
                )
            )
        }
        currentEpisodeHasReached = currentEpisodeHasReached || !reaches.isEmpty
        return reaches
    }

    private mutating func beginEpisodeIfNeeded(
        precedingSampleCount: Int,
        traceEligible: Bool
    ) {
        guard startedAtSampleCount == nil else { return }
        startedAtSampleCount = precedingSampleCount
        currentEpisodeNumber = nextEpisodeNumber
        nextEpisodeNumber += 1
        currentEpisodeIsTraceable = traceEligible
    }

    private mutating func clearCurrentEpisode() {
        silenceSampleCount = 0
        startedAtSampleCount = nil
        consecutiveSpeechFrameCount = 0
        currentEpisodeNumber = nil
        currentEpisodeIsTraceable = false
        currentEpisodeHasReached = false
    }
}
