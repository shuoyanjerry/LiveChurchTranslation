enum ASRQualificationSegmentRules {
    static func validate(_ clip: ASRQualificationClipV2) throws {
        var previous: ASRQualificationSegmentV2?
        var loadedClipSamples = 0
        for (index, segment) in clip.segments.enumerated() {
            try validateSequence(segment, index: index, clipID: clip.id)
            try validateOrder(segment, after: previous, clipID: clip.id)
            let loadedSegmentSamples = try validateRangeAndAccounting(segment, of: clip)
            loadedClipSamples = try ASRQualificationSampleLimitRules.addingToClipTotal(
                loadedSegmentSamples,
                current: loadedClipSamples,
                clipID: clip.id
            )
            try validateTextAndHash(segment, clipID: clip.id)
            previous = segment
        }
    }

    private static func validateSequence(
        _ segment: ASRQualificationSegmentV2,
        index: Int,
        clipID: String
    ) throws {
        let expected = index + 1
        guard segment.sequence == expected else {
            throw ASRQualificationError.invalidSequence(
                clipID: clipID,
                expected: expected,
                actual: segment.sequence
            )
        }
    }

    private static func validateOrder(
        _ segment: ASRQualificationSegmentV2,
        after previous: ASRQualificationSegmentV2?,
        clipID: String
    ) throws {
        guard let previous else { return }
        guard segment.startSample > previous.startSample,
            segment.endSample > previous.endSample
        else {
            throw ASRQualificationError.nonIncreasingSegmentOrder(
                clipID: clipID,
                sequence: segment.sequence
            )
        }
    }

    private static func validateRangeAndAccounting(
        _ segment: ASRQualificationSegmentV2,
        of clip: ASRQualificationClipV2
    ) throws -> Int {
        guard segment.startSample >= 0,
            segment.startSample < segment.endSample,
            segment.endSample <= clip.totalSamples
        else {
            throw ASRQualificationError.invalidSegmentRange(
                clipID: clip.id,
                sequence: segment.sequence
            )
        }
        let (loadedSamples, overflow) = segment.validSampleCount.addingReportingOverflow(
            segment.syntheticPaddingSamples
        )
        guard segment.validSampleCount >= 0,
            segment.syntheticPaddingSamples >= 0,
            !overflow,
            segment.validSampleCount == segment.endSample - segment.startSample
        else {
            throw ASRQualificationError.invalidSampleAccounting(
                clipID: clip.id,
                sequence: segment.sequence
            )
        }
        try ASRQualificationSampleLimitRules.validateSegment(
            segment,
            loadedSamples: loadedSamples,
            clipID: clip.id
        )
        return loadedSamples
    }

    private static func validateTextAndHash(
        _ segment: ASRQualificationSegmentV2,
        clipID: String
    ) throws {
        guard !ASRQualificationScalarRules.isBlank(segment.endReason) else {
            throw ASRQualificationError.emptyEndReason(
                clipID: clipID,
                sequence: segment.sequence
            )
        }
        try ASRQualificationScalarRules.validateHash(
            segment.pcmSHA256,
            path: "\(clipID).segments[\(segment.sequence)].pcmSHA256"
        )
    }
}
