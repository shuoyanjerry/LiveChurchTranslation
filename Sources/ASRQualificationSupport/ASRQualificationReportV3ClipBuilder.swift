import Foundation

private struct ASRQualificationClipDurationsV3 {
    let source: Double
    let decoded: Double
    let unionSamples: Int
}

enum ASRQualificationReportV3ClipBuilder {
    static func build(
        input: ASRQualificationClipEvaluationInputV3,
        manifestClip: ASRQualificationClipV2
    ) throws -> ASRQualificationClipReportV3 {
        let sourceSeconds = try validateIdentity(input, manifestClip: manifestClip)
        try ASRQualificationReportV3AttemptValidator.validate(
            input.attempts,
            segments: manifestClip.segments,
            clipID: input.id
        )
        let hypothesis = input.attempts.compactMap { attempt in
            attempt.status == .success ? attempt.hypothesis : nil
        }.joined(separator: "\n")
        let decodedSeconds = try decodedInputSeconds(
            attempts: input.attempts,
            sampleRate: manifestClip.sampleRate,
            clipID: input.id
        )
        let unionSamples = try ASRQualificationReportV3Math.unionSampleCount(
            manifestClip.segments,
            path: "clips.\(input.id).unionCoveredSamples"
        )
        return try report(
            input: input,
            manifestClip: manifestClip,
            durations: .init(
                source: sourceSeconds,
                decoded: decodedSeconds,
                unionSamples: unionSamples
            ),
            hypothesis: hypothesis
        )
    }

    private static func report(
        input: ASRQualificationClipEvaluationInputV3,
        manifestClip: ASRQualificationClipV2,
        durations: ASRQualificationClipDurationsV3,
        hypothesis: String
    ) throws -> ASRQualificationClipReportV3 {
        let strict = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: input.referenceText,
            hypothesis: hypothesis
        )
        let pronouns = ASRQualificationTextMetrics.normalizedStrictPronounConfusion(
            reference: input.referenceText,
            hypothesis: hypothesis
        )
        let timing = try ASRQualificationReportV3Math.timing(
            attempts: input.attempts,
            decodedInputSeconds: durations.decoded,
            path: "clips.\(input.id)"
        )
        return ASRQualificationClipReportV3(
            id: input.id,
            referenceText: input.referenceText,
            hypothesisText: hypothesis,
            allowsHypothesisEdgeInsertions: manifestClip.allowsHypothesisEdgeInsertions,
            sourceAudioSeconds: durations.source,
            decodedInputSeconds: durations.decoded,
            unionCoveredSourceSeconds: Double(durations.unionSamples)
                / Double(manifestClip.sampleRate),
            attempts: input.attempts,
            strictCER: strict,
            edgeFreeSemiglobalCER: edgeMetric(
                input: input,
                hypothesis: hypothesis,
                manifestClip: manifestClip
            ),
            strictPronounConfusion: pronouns,
            timing: timing
        )
    }

    private static func validateIdentity(
        _ input: ASRQualificationClipEvaluationInputV3,
        manifestClip: ASRQualificationClipV2
    ) throws -> Double {
        guard input.segments == manifestClip.segments else {
            throw ASRQualificationReportV3Error.segmentDefinitionsMismatch(clipID: input.id)
        }
        guard input.sourceAudioSeconds.isFinite, input.sourceAudioSeconds >= 0 else {
            throw ASRQualificationReportV3Error.invalidSourceAudioSeconds(clipID: input.id)
        }
        let sourceSeconds = Double(manifestClip.totalSamples) / Double(manifestClip.sampleRate)
        guard input.sourceAudioSeconds == sourceSeconds else {
            throw ASRQualificationReportV3Error.sourceAudioSecondsMismatch(clipID: input.id)
        }
        let actualHash = QualificationSHA256.data(Data(input.referenceText.utf8))
        guard actualHash == manifestClip.referenceSHA256 else {
            throw ASRQualificationReportV3Error.referenceSHA256Mismatch(
                clipID: input.id,
                expected: manifestClip.referenceSHA256,
                actual: actualHash
            )
        }
        return sourceSeconds
    }

    private static func decodedInputSeconds(
        attempts: [ASRQualificationAttemptV3],
        sampleRate: Int,
        clipID: String
    ) throws -> Double {
        let samples = try ASRQualificationReportV3Math.checkedSum(
            attempts.map(\.inputSampleCount),
            path: "clips.\(clipID).decodedInputSamples"
        )
        return Double(samples) / Double(sampleRate)
    }

    private static func edgeMetric(
        input: ASRQualificationClipEvaluationInputV3,
        hypothesis: String,
        manifestClip: ASRQualificationClipV2
    ) -> ASRCharacterErrorMeasurement? {
        guard manifestClip.allowsHypothesisEdgeInsertions else { return nil }
        return ASRQualificationTextMetrics.normalizedEdgeFreeSemiglobalCER(
            reference: input.referenceText,
            hypothesis: hypothesis
        )
    }
}
