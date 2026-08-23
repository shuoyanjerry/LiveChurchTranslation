enum ASRQualificationSampleLimitRules {
    static func validateSegment(
        _ segment: ASRQualificationSegmentV2,
        loadedSamples: Int,
        clipID: String
    ) throws {
        let limits = ASRQualificationResourceLimits.self
        guard segment.syntheticPaddingSamples <= limits.maximumSyntheticPaddingSamples else {
            throw ASRQualificationError.syntheticPaddingLimitExceeded(
                clipID: clipID,
                sequence: segment.sequence,
                value: segment.syntheticPaddingSamples,
                maximum: limits.maximumSyntheticPaddingSamples
            )
        }
        guard loadedSamples <= limits.maximumLoadedSegmentSamples else {
            throw ASRQualificationError.loadedSampleLimitExceeded(
                clipID: clipID,
                sequence: segment.sequence,
                value: loadedSamples,
                maximum: limits.maximumLoadedSegmentSamples
            )
        }
    }

    static func addingToClipTotal(
        _ segmentSamples: Int,
        current: Int,
        clipID: String
    ) throws -> Int {
        let (total, overflow) = current.addingReportingOverflow(segmentSamples)
        guard !overflow,
            total <= ASRQualificationResourceLimits.maximumLoadedClipSamples
        else {
            throw ASRQualificationError.loadedClipSampleLimitExceeded(
                clipID: clipID,
                maximum: ASRQualificationResourceLimits.maximumLoadedClipSamples
            )
        }
        return total
    }
}
