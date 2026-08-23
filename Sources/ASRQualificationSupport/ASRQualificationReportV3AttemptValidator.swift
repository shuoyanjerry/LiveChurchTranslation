enum ASRQualificationReportV3AttemptValidator {
    static func validate(
        _ attempts: [ASRQualificationAttemptV3],
        segments: [ASRQualificationSegmentV2],
        clipID: String
    ) throws {
        guard attempts.count == segments.count else {
            throw ASRQualificationReportV3Error.attemptCountMismatch(
                clipID: clipID,
                expected: segments.count,
                actual: attempts.count
            )
        }
        for (attempt, segment) in zip(attempts, segments) {
            try validate(attempt, segment: segment, clipID: clipID)
        }
    }

    private static func validate(
        _ attempt: ASRQualificationAttemptV3,
        segment: ASRQualificationSegmentV2,
        clipID: String
    ) throws {
        guard attempt.sequence == segment.sequence else {
            throw ASRQualificationReportV3Error.attemptSequenceMismatch(
                clipID: clipID,
                expected: segment.sequence,
                actual: attempt.sequence
            )
        }
        let expectedCount = try ASRQualificationReportV3Math.checkedAdd(
            segment.validSampleCount,
            segment.syntheticPaddingSamples,
            path: "clips.\(clipID).segments.\(segment.sequence).inputSampleCount"
        )
        guard attempt.inputSampleCount == expectedCount else {
            throw ASRQualificationReportV3Error.attemptInputSampleCountMismatch(
                clipID: clipID,
                sequence: segment.sequence,
                expected: expectedCount,
                actual: attempt.inputSampleCount
            )
        }
        guard attempt.pcmSHA256 == segment.pcmSHA256 else {
            throw ASRQualificationReportV3Error.attemptPCMHashMismatch(
                clipID: clipID,
                sequence: segment.sequence,
                expected: segment.pcmSHA256,
                actual: attempt.pcmSHA256
            )
        }
        guard attempt.elapsedSeconds.isFinite, attempt.elapsedSeconds >= 0 else {
            throw ASRQualificationReportV3Error.invalidElapsedSeconds(
                clipID: clipID,
                sequence: segment.sequence
            )
        }
        try validatePayload(attempt, clipID: clipID)
    }

    private static func validatePayload(
        _ attempt: ASRQualificationAttemptV3,
        clipID: String
    ) throws {
        switch attempt.status {
        case .success:
            guard attempt.hypothesis != nil else {
                throw ASRQualificationReportV3Error.successfulAttemptMissingHypothesis(
                    clipID: clipID,
                    sequence: attempt.sequence
                )
            }
            guard attempt.failureCode == nil else {
                throw ASRQualificationReportV3Error.successfulAttemptHasFailureCode(
                    clipID: clipID,
                    sequence: attempt.sequence
                )
            }
        case .failure:
            try validateFailurePayload(attempt, clipID: clipID)
        }
    }

    private static func validateFailurePayload(
        _ attempt: ASRQualificationAttemptV3,
        clipID: String
    ) throws {
        guard attempt.hypothesis == nil else {
            throw ASRQualificationReportV3Error.failedAttemptHasHypothesis(
                clipID: clipID,
                sequence: attempt.sequence
            )
        }
        guard let code = attempt.failureCode,
            !code.isEmpty,
            !code.allSatisfy(\.isWhitespace)
        else {
            throw ASRQualificationReportV3Error.failedAttemptMissingFailureCode(
                clipID: clipID,
                sequence: attempt.sequence
            )
        }
    }
}
