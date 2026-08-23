import Foundation

enum CandidatePauseBenchmarkHarness {
    static let expectedSourceReportSHA256 =
        "1e08732048af648cf0e571c2aaccdc4722a943fb28fcb641f6d172df11cd32ff"

    static func run(environment: [String: String]) async throws {
        guard let input = CandidatePauseHarnessInput(environment: environment) else { return }
        let entries = try VADBenchmarkCorpus.entries(
            in: input.wavDirectory
        )
        let loaded = try CandidatePauseSourceDocument.load(
            from: input.sourceReport,
            entries: entries
        )
        try validateFrozenBaseline(loaded)
        let sourceBefore = try CandidatePauseHashing.boundSourceFingerprints(
            workspaceRoot: input.workspace
        )
        let reports = try await replay(entries: entries, source: loaded.document.selected.files)
        try validateStableInputs(
            sourceURL: input.sourceReport,
            sourceFingerprint: loaded.fingerprint,
            sourceBefore: sourceBefore,
            workspace: input.workspace
        )
        let document = try makeDocument(
            files: reports,
            sourceFingerprint: loaded.fingerprint,
            sourceFingerprinting: sourceBefore
        )
        let data = try CandidatePauseReportEncoder.encode(
            document,
            forbiddenValues: input.privateValues(entries: entries)
        )
        try CandidatePauseHarnessOutput.write(
            data,
            aggregate: document.aggregate,
            input: input
        )
    }

    private static func validateFrozenBaseline(
        _ loaded: (document: CandidatePauseSourceDocument, fingerprint: VADAudioFingerprint)
    ) throws {
        let files = loaded.document.selected.files
        let seconds = files.reduce(0) { $0 + $1.audioSeconds }
        guard loaded.fingerprint.sha256 == expectedSourceReportSHA256,
            files.count == 14, abs(seconds - 27_524.215_375) <= 0.000_000_001
        else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("frozen baseline mismatch")
        }
    }

    private static func replay(
        entries: [VADCorpusEntry],
        source: [CandidatePauseSourceFile]
    ) async throws -> [CandidatePauseFileReport] {
        var reports: [CandidatePauseFileReport] = []
        for pair in zip(entries, source) {
            reports.append(try await CandidatePauseBenchmarkRunner().replay(pair.0, source: pair.1))
        }
        return reports
    }

    private static func validateStableInputs(
        sourceURL: URL,
        sourceFingerprint: VADAudioFingerprint,
        sourceBefore: CandidatePauseBoundSources,
        workspace: URL
    ) throws {
        guard try VADBenchmarkCorpus.fingerprint(sourceURL) == sourceFingerprint,
            try CandidatePauseHashing.boundSourceFingerprints(workspaceRoot: workspace)
                == sourceBefore
        else { throw CandidatePauseBenchmarkError.invalidTrace("qualification input changed") }
    }

    private static func makeDocument(
        files: [CandidatePauseFileReport],
        sourceFingerprint: VADAudioFingerprint,
        sourceFingerprinting: CandidatePauseBoundSources
    ) throws -> CandidatePauseBenchmarkDocument {
        CandidatePauseBenchmarkDocument(
            frameSampleCount: 320,
            sampleRateHz: 16_000,
            provenance: CandidatePauseProvenance(
                sourceReportSHA256: sourceFingerprint.sha256,
                sourceReportByteCount: sourceFingerprint.byteCount,
                selectedConfigurationSHA256:
                    try CandidatePauseHashing
                    .selectedConfigurationDigest(),
                productionVADSourceSHA256: sourceFingerprinting.production.sha256,
                productionVADSourceFileCount: sourceFingerprinting.production.fileCount,
                companionSourceSHA256: sourceFingerprinting.companion.sha256,
                companionSourceFileCount: sourceFingerprinting.companion.fileCount
            ),
            runtimeCaveats: [
                "Shadow observations never alter or veto production endpoint decisions.",
                "Replay runtime is host- and load-dependent and is not an SLA measurement.",
                "Legacy EOF-only synthetic padding is reconciled explicitly in sample counts.",
                "No boundary accuracy claim is valid without locked independent human labels.",
            ],
            files: files,
            aggregate: CandidatePauseAggregateBuilder.make(files: files)
        )
    }

}
