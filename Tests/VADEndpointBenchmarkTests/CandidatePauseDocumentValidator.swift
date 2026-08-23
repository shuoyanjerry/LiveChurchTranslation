enum CandidatePauseDocumentValidator {
    static func validate(_ document: CandidatePauseBenchmarkDocument) throws {
        guard document.mode == "shadowOnly", document.decisionAuthority == "none",
            document.sourceStrategy == "webrtcStable", document.sampleRateHz == 16_000,
            document.frameSampleCount == 320
        else { throw CandidatePauseBenchmarkError.invalidTrace("authority invariant failed") }
        try validateProvenance(document.provenance)
        for file in document.files {
            try validate(file)
        }
        guard Set(document.files.map(\.clipID)).count == document.files.count else {
            throw CandidatePauseBenchmarkError.invalidTrace("duplicate clip")
        }
        guard CandidatePauseAggregateBuilder.make(files: document.files) == document.aggregate else {
            throw CandidatePauseBenchmarkError.invalidTrace("aggregate mismatch")
        }
    }

    private static func validateProvenance(_ value: CandidatePauseProvenance) throws {
        guard CandidatePauseDigestValidator.isSHA256(value.sourceReportSHA256),
            CandidatePauseDigestValidator.isSHA256(value.selectedConfigurationSHA256),
            CandidatePauseDigestValidator.isSHA256(value.productionVADSourceSHA256),
            CandidatePauseDigestValidator.isSHA256(value.companionSourceSHA256),
            value.sourceReportByteCount > 0,
            value.productionVADSourceFileCount > 0,
            value.companionSourceFileCount > 0
        else { throw CandidatePauseBenchmarkError.invalidTrace("provenance invariant failed") }
    }

    private static func validate(_ file: CandidatePauseFileReport) throws {
        let expectedOrdinals = file.events.indices.map { $0 + 1 }
        guard file.clipID.hasPrefix("sermon-"),
            CandidatePauseDigestValidator.isSHA256(file.sourceWAVSHA256),
            file.sourceWAVByteCount > 0, file.totalSamples > 0,
            candidatePauseSeconds(file.totalSamples, match: file.audioSeconds),
            file.sourceBoundaryCount == file.finalizedBoundaries.count,
            (0..<320).contains(file.sourceEOFPaddingSamples),
            (0...1).contains(file.sourceEOFLagCount),
            file.events.map(\.ordinal) == expectedOrdinals
        else { throw CandidatePauseBenchmarkError.invalidTrace("file invariant failed") }
        try validateBoundaries(file.finalizedBoundaries, totalSamples: file.totalSamples)
        try CandidatePauseEventValidator.validate(
            file.events,
            boundaries: file.finalizedBoundaries
        )
    }

    private static func validateBoundaries(
        _ boundaries: [CandidatePauseFinalizedBoundary],
        totalSamples: Int64
    ) throws {
        guard Set(boundaries.map(\.sequenceNumber)).count == boundaries.count else {
            throw CandidatePauseBenchmarkError.invalidTrace("duplicate boundary sequence")
        }
        let allowedReasons = Set([
            "trailingSilence", "softSilence", "maximumBoundary", "maximumDuration",
            "endOfStream",
        ])
        for value in boundaries {
            guard value.startSample >= 0, value.endSample >= value.startSample,
                Int64(value.endSample) <= totalSamples,
                value.validSampleCount == value.endSample - value.startSample,
                CandidatePauseDigestValidator.isSHA256(value.pcmSHA256),
                allowedReasons.contains(value.reason),
                candidatePauseSeconds(Int64(value.startSample), match: value.startedAtSeconds),
                candidatePauseSeconds(Int64(value.endSample), match: value.endedAtSeconds),
                abs(
                    value.endedAtSeconds - value.startedAtSeconds
                        - Double(value.validSampleCount) / 16_000
                ) <= 0.000_000_001
            else { throw CandidatePauseBenchmarkError.invalidTrace("boundary invariant failed") }
        }
    }

}
