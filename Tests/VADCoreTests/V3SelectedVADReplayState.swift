import Foundation

struct V3SelectedVADReplayState {
    var consumedSamples: Int64 = 0
    var signatures: [V3SelectedVADVoiceSignature] = []
    var traceCounter = V3SelectedVADTraceCounter()

    mutating func append(
        production: [V3SelectedVADVoiceSignature],
        shadow: [V3SelectedVADVoiceSignature]
    ) throws {
        guard production == shadow else { throw V3SelectedVADError.parityMismatch }
        signatures += production
    }

    func metrics() throws -> V3SelectedVADTrackMetrics {
        let digest = try V3SelectedVADHashing.canonicalDigest(signatures)
        let ended = signatures.filter { $0.kind == "speechEnded" }
        let durations = ended.compactMap(\.sampleCount)
        let reasons = ended.compactMap(\.reason).reduce(into: [:]) {
            $0[$1, default: 0] += 1
        }
        return V3SelectedVADTrackMetrics(
            productionVoiceSignatureSHA256: digest,
            shadowVoiceSignatureSHA256: digest,
            productionShadowParity: true,
            speechStartedCount: signatures.count { $0.kind == "speechStarted" },
            segmentCount: ended.count,
            underTwoSecondsCount: durations.count { $0 < 32_000 },
            reasonCounts: reasons,
            segmentDurationSamples: durations,
            candidateReachedCounts: traceCounter.reached,
            candidateResolutionCounts: traceCounter.resolutions
        )
    }
}
