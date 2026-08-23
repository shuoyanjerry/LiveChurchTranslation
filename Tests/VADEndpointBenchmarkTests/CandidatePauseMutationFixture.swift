enum CandidatePauseMutationFixture {
    static func validDocument() async throws -> CandidatePauseBenchmarkDocument {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 420)
        return CandidatePauseSyntheticDocument.make(file: try await capture.finish())
    }

    static func document(
        _ original: CandidatePauseBenchmarkDocument,
        events: [CandidatePauseEventRecord]
    ) -> CandidatePauseBenchmarkDocument {
        copyDocument(original, file: copyFile(original.files[0], events: events))
    }

    static func ordinal(
        _ value: CandidatePauseEventRecord,
        _ ordinal: Int
    ) -> CandidatePauseEventRecord {
        copy(value, ordinal: ordinal)
    }

    static func kind(
        _ value: CandidatePauseEventRecord,
        _ kind: String
    ) -> CandidatePauseEventRecord {
        copy(value, kind: kind)
    }

    static func shiftedCandidateEnd(
        _ value: CandidatePauseEventRecord,
        by samples: Int64
    ) -> CandidatePauseEventRecord {
        guard let source = value.reached else { return value }
        let reached = CandidatePauseReachedRecord(
            thresholdMilliseconds: source.thresholdMilliseconds,
            thresholdSampleCount: source.thresholdSampleCount,
            candidateEndSourceSample: source.candidateEndSourceSample + samples,
            candidateEndSeconds: Double(source.candidateEndSourceSample + samples) / 16_000,
            observationStartSourceSample: source.observationStartSourceSample,
            observationEndSourceSample: source.observationEndSourceSample,
            observationEndSeconds: source.observationEndSeconds,
            overshootSampleCount: source.overshootSampleCount - samples
        )
        return copy(value, reached: reached)
    }

    static func resolution(
        _ value: CandidatePauseEventRecord,
        _ resolution: CandidatePauseResolutionRecord
    ) -> CandidatePauseEventRecord {
        copy(value, resolution: resolution)
    }

    static func boundaryReason(
        _ value: CandidatePauseEventRecord,
        _ reason: String
    ) -> CandidatePauseEventRecord {
        let source = value.finalizedBoundary
        let boundary = CandidatePauseFinalizedBoundary(
            sequenceNumber: source.sequenceNumber,
            startSample: source.startSample,
            endSample: source.endSample,
            validSampleCount: source.validSampleCount,
            pcmSHA256: source.pcmSHA256,
            startedAtSeconds: source.startedAtSeconds,
            endedAtSeconds: source.endedAtSeconds,
            reason: reason
        )
        return copy(value, boundary: boundary)
    }

    static func provenanceDigest(
        _ original: CandidatePauseBenchmarkDocument,
        digest: String
    ) -> CandidatePauseBenchmarkDocument {
        let source = original.provenance
        return CandidatePauseBenchmarkDocument(
            frameSampleCount: original.frameSampleCount,
            sampleRateHz: original.sampleRateHz,
            provenance: CandidatePauseProvenance(
                sourceReportSHA256: digest,
                sourceReportByteCount: source.sourceReportByteCount,
                selectedConfigurationSHA256: source.selectedConfigurationSHA256,
                productionVADSourceSHA256: source.productionVADSourceSHA256,
                productionVADSourceFileCount: source.productionVADSourceFileCount,
                companionSourceSHA256: source.companionSourceSHA256,
                companionSourceFileCount: source.companionSourceFileCount
            ),
            runtimeCaveats: original.runtimeCaveats,
            files: original.files,
            aggregate: original.aggregate
        )
    }

    static func copy(
        _ value: CandidatePauseEventRecord,
        ordinal: Int? = nil,
        kind: String? = nil,
        reached: CandidatePauseReachedRecord? = nil,
        resolution: CandidatePauseResolutionRecord? = nil,
        boundary: CandidatePauseFinalizedBoundary? = nil
    ) -> CandidatePauseEventRecord {
        CandidatePauseEventRecord(
            ordinal: ordinal ?? value.ordinal,
            kind: kind ?? value.kind,
            sequenceNumber: value.sequenceNumber,
            episodeNumber: value.episodeNumber,
            observedAtSourceSample: value.observedAtSourceSample,
            observedAtSeconds: value.observedAtSeconds,
            emittedAfterSourceSample: value.emittedAfterSourceSample,
            reached: reached ?? value.reached,
            resolution: resolution ?? value.resolution,
            finalizedBoundary: boundary ?? value.finalizedBoundary
        )
    }
}
