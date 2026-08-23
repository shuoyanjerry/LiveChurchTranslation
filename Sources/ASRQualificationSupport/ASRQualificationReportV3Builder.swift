import Foundation

/// Validates frozen inputs and constructs Report V3 without provider dependencies.
public struct ASRQualificationReportV3Builder: Sendable {
    public init() {}

    public func build(
        generatedAt: Date = Date(),
        qualificationManifestSHA256: String,
        manifest: ASRQualificationManifestV2,
        provider: ASRQualificationProviderMetadataV3,
        environment: ASRQualificationEnvironmentV3,
        clips: [ASRQualificationClipEvaluationInputV3]
    ) throws -> ASRQualificationReportV3 {
        try ASRQualificationReportV3Rules.validateHeader(
            generatedAt: generatedAt,
            manifestSHA256: qualificationManifestSHA256,
            manifest: manifest,
            provider: provider,
            environment: environment
        )
        let inputs = try ASRQualificationReportV3Rules.indexInputs(
            clips,
            manifest: manifest
        )
        let reports = try buildReports(manifest: manifest, inputs: inputs)
        return ASRQualificationReportV3(
            schemaVersion: 3,
            generatedAt: generatedAt,
            corpusID: manifest.corpusID,
            qualificationManifestSHA256: qualificationManifestSHA256,
            provider: provider,
            environment: environment,
            clips: reports,
            aggregate: try ASRQualificationReportV3AggregateBuilder.build(reports)
        )
    }

    private func buildReports(
        manifest: ASRQualificationManifestV2,
        inputs: [String: ASRQualificationClipEvaluationInputV3]
    ) throws -> [ASRQualificationClipReportV3] {
        try manifest.clips.map { manifestClip in
            guard let input = inputs[manifestClip.id] else {
                throw ASRQualificationReportV3Error.clipSetMismatch(
                    expected: manifest.clips.map(\.id).sorted(),
                    actual: inputs.keys.sorted()
                )
            }
            return try ASRQualificationReportV3ClipBuilder.build(
                input: input,
                manifestClip: manifestClip
            )
        }
    }
}
