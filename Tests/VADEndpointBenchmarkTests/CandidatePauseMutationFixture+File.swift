extension CandidatePauseMutationFixture {
    static func fileAudioSeconds(
        _ original: CandidatePauseBenchmarkDocument,
        value: Double
    ) -> CandidatePauseBenchmarkDocument {
        let source = original.files[0]
        let file = copyFile(source, audioSeconds: value)
        return copyDocument(original, file: file)
    }

    static func finalizedBoundary(
        _ original: CandidatePauseBenchmarkDocument,
        endSample: Int? = nil,
        endedAtSeconds: Double? = nil,
        pcmSHA256: String? = nil,
        reason: String? = nil
    ) -> CandidatePauseBenchmarkDocument {
        let source = original.files[0]
        let old = source.finalizedBoundaries[0]
        let end = endSample ?? old.endSample
        let boundary = CandidatePauseFinalizedBoundary(
            sequenceNumber: old.sequenceNumber,
            startSample: old.startSample,
            endSample: end,
            validSampleCount: end - old.startSample,
            pcmSHA256: pcmSHA256 ?? old.pcmSHA256,
            startedAtSeconds: old.startedAtSeconds,
            endedAtSeconds: endedAtSeconds ?? Double(end) / 16_000,
            reason: reason ?? old.reason
        )
        let events = source.events.map { copy($0, boundary: boundary) }
        let file = copyFile(source, boundaries: [boundary], events: events)
        return copyDocument(original, file: file)
    }

    static func copyFile(
        _ source: CandidatePauseFileReport,
        audioSeconds: Double? = nil,
        boundaries: [CandidatePauseFinalizedBoundary]? = nil,
        events: [CandidatePauseEventRecord]? = nil
    ) -> CandidatePauseFileReport {
        CandidatePauseFileReport(
            clipID: source.clipID,
            sourceWAVSHA256: source.sourceWAVSHA256,
            sourceWAVByteCount: source.sourceWAVByteCount,
            totalSamples: source.totalSamples,
            audioSeconds: audioSeconds ?? source.audioSeconds,
            sourceBoundaryCount: source.sourceBoundaryCount,
            sourceEOFPaddingSamples: source.sourceEOFPaddingSamples,
            sourceEOFLagCount: source.sourceEOFLagCount,
            finalizedBoundaries: boundaries ?? source.finalizedBoundaries,
            events: events ?? source.events
        )
    }

    static func copyDocument(
        _ original: CandidatePauseBenchmarkDocument,
        file: CandidatePauseFileReport
    ) -> CandidatePauseBenchmarkDocument {
        CandidatePauseBenchmarkDocument(
            frameSampleCount: original.frameSampleCount,
            sampleRateHz: original.sampleRateHz,
            provenance: original.provenance,
            runtimeCaveats: original.runtimeCaveats,
            files: [file],
            aggregate: CandidatePauseAggregateBuilder.make(files: [file])
        )
    }
}
