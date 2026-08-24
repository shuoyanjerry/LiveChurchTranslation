import Foundation
import Testing
import TranslationQualificationSupport

enum HyMTPostflightTestFixture {
    static func make() throws -> Evidence {
        let corpus = try makeCorpus()
        let configuration = makeConfiguration()
        let provenance = TranslationExecutionProvenance(
            buildConfiguration: "release",
            sourceBundle: bundle("1"),
            testExecutable: artifact("2"),
            model: artifact("3"),
            helper: artifact("4"),
            runtimeBundle: bundle("5"),
            configurationSHA256: try TranslationConfigurationHasher.hash(
                settings: configuration.providerSettings
            ),
            manifestSHA256: corpus.manifestSHA256,
            corpusSchemaSHA256: corpus.schemaSHA256
        )
        let attempt = try failureAttempt(corpus)
        let report = try makeReport(
            corpus: corpus,
            configuration: configuration,
            provenance: provenance,
            attempt: attempt
        )
        return Evidence(
            corpus: corpus,
            configuration: configuration,
            provenance: provenance,
            report: report,
            snapshot: try makeSnapshot(report)
        )
    }

    struct Evidence {
        let corpus: TranslationQualificationCorpus
        let configuration: HyMTQualificationConfiguration
        let provenance: TranslationExecutionProvenance
        let report: TranslationQualificationReport
        let snapshot: HyMTQualificationReportSnapshot
    }
}

extension HyMTPostflightTestFixture {
    private static func makeSnapshot(
        _ report: TranslationQualificationReport
    ) throws -> HyMTQualificationReportSnapshot {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(report)
        return HyMTQualificationReportSnapshot(
            data: data,
            sha256: TranslationQualificationSHA256.hash(data: data)
        )
    }

    private static func makeReport(
        corpus: TranslationQualificationCorpus,
        configuration: HyMTQualificationConfiguration,
        provenance: TranslationExecutionProvenance,
        attempt: TranslationQualificationAttempt
    ) throws -> TranslationQualificationReport {
        try TranslationQualificationReportBuilder.build(
            generatedAt: "2026-08-22T12:00:00Z",
            corpus: corpus,
            provider: HyMTQualificationPostflightIdentity.provider(
                configuration: configuration,
                provenance: provenance
            ),
            environment: HyMTQualificationPostflightIdentity.environment(
                configuration: configuration
            ),
            executionProvenance: provenance,
            attempts: [attempt]
        )
    }

    private static func failureAttempt(
        _ corpus: TranslationQualificationCorpus
    ) throws -> TranslationQualificationAttempt {
        let segment = try #require(corpus.manifest.segments.first)
        let preservation = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: nil,
            terms: []
        )
        return TranslationQualificationAttempt(
            segment: segment,
            status: .failure,
            hypothesisEnglish: nil,
            translationSourceText: segment.observedASRAmbiguousChinese,
            contextSegmentIDs: [],
            strictRetryUsed: false,
            completionAttemptCount: 0,
            completionOutcomes: [],
            latencySeconds: 0.1,
            failureCode: "hymt.transport-failure",
            glossaryTerms: preservation.terms,
            preservationChecks: preservation.checks + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: .notApplicable
                )
            ],
            pronounResults: []
        )
    }

    private static func makeConfiguration() -> HyMTQualificationConfiguration {
        HyMTQualificationConfiguration(
            workspaceRoot: URL(fileURLWithPath: "/synthetic-workspace", isDirectory: true),
            manifestURL: URL(fileURLWithPath: "/synthetic-manifest.json"),
            reportFilename: "synthetic-report.json",
            reviewPacketFilename: "synthetic-report.review-packet.json",
            freezeRequestFilename: "synthetic-report.freeze-request.json",
            modelURL: URL(fileURLWithPath: "/synthetic-model", isDirectory: true),
            helperURL: URL(fileURLWithPath: "/synthetic-runtime/llama-server"),
            backgroundLoad: "synthetic-idle",
            expectedSourceBundleSHA256: sha("1"),
            expectedTestExecutableSHA256: sha("2")
        )
    }

    static func temporaryWorkspace() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hymt-postflight-\(UUID().uuidString)", isDirectory: true)
        let reports = root.appendingPathComponent(
            ".artifacts/translation-qualification",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: reports,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: 0o700)]
        )
        return root
    }

    private static func makeCorpus() throws -> TranslationQualificationCorpus {
        let data = try JSONSerialization.data(withJSONObject: manifest)
        let value = try TranslationQualificationManifestDecoder.decode(data)
        return TranslationQualificationCorpus(
            manifest: value,
            manifestSHA256: sha("a"),
            schemaSHA256: sha("b")
        )
    }

    private static func artifact(_ character: Character) -> TranslationQualificationArtifactDigest {
        TranslationQualificationArtifactDigest(byteCount: 1, sha256: sha(character))
    }

    private static func bundle(_ character: Character) -> TranslationQualificationBundleDigest {
        TranslationQualificationBundleDigest(
            format: TranslationExecutionProvenance.bundleFormat,
            entryCount: 1,
            byteCount: 1,
            sha256: sha(character)
        )
    }

    static func sha(_ character: Character) -> String {
        String(repeating: String(character), count: 64)
    }

}
