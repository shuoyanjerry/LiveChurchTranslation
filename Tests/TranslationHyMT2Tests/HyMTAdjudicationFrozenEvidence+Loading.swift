import Foundation
import TranslationQualificationSupport

extension HyMTAdjudicationFrozenEvidence {
    static func loadSignedFreeze(at url: URL) throws -> SignedFreeze {
        let snapshot = try HyMTQualificationPrivateFile.snapshot(
            at: url,
            maximumByteCount: 1_024 * 1_024
        )
        let verified = try TranslationQualificationFreezeVerifier.verify(
            snapshot.data,
            trustPolicy: HyMTQualificationTrustPolicy.productionFreeze
        )
        return SignedFreeze(snapshot: snapshot, verified: verified)
    }

    static func loadReportSnapshot(
        _ configuration: HyMTQualificationConfiguration
    ) throws -> HyMTQualificationReportSnapshot {
        try HyMTQualificationReportSnapshot.load(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
    }

    static func loadPostflight(
        configuration: HyMTQualificationConfiguration,
        corpus: TranslationQualificationCorpus,
        provenance: TranslationExecutionProvenance,
        reportSnapshot: HyMTQualificationReportSnapshot,
        expectedSHA256: String
    ) throws -> (
        snapshot: HyMTQualificationPrivateSnapshot,
        attestation: HyMTQualificationPostflightAttestation
    ) {
        let filename = configuration.reportFilename + ".postflight.json"
        let snapshot = try privateArtifact(
            filename,
            configuration: configuration,
            expectedSHA256: expectedSHA256,
            maximumByteCount: 1_024 * 1_024
        )
        try TranslationJSONDuplicateKeyValidator.validate(snapshot.data)
        let stored = try JSONDecoder().decode(
            HyMTQualificationPostflightAttestation.self,
            from: snapshot.data
        )
        let rebuilt = try HyMTQualificationPostflightValidator.validate(
            snapshot: reportSnapshot,
            corpus: corpus,
            provenance: provenance,
            configuration: configuration,
            timestamp: stored.postflightTimestamp
        )
        guard stored == rebuilt else { throw invalid }
        return (snapshot, stored)
    }

    static func privateArtifact(
        _ filename: String,
        configuration: HyMTQualificationConfiguration,
        expectedSHA256: String,
        maximumByteCount: Int
    ) throws -> HyMTQualificationPrivateSnapshot {
        let snapshot = try HyMTQualificationPrivateFile.snapshot(
            at: artifactURL(filename, configuration: configuration),
            maximumByteCount: maximumByteCount
        )
        guard snapshot.sha256 == expectedSHA256 else { throw invalid }
        return snapshot
    }

    func requirePrivateArtifactUnchanged(
        _ filename: String,
        snapshot: HyMTQualificationPrivateSnapshot,
        maximumByteCount: Int
    ) throws {
        _ = try HyMTQualificationPrivateFile.read(
            at: Self.artifactURL(filename, configuration: configuration),
            expectedSHA256: snapshot.sha256,
            maximumByteCount: maximumByteCount
        )
    }

    static func artifactURL(
        _ filename: String,
        configuration: HyMTQualificationConfiguration
    ) -> URL {
        configuration.workspaceRoot
            .appendingPathComponent(".artifacts/translation-qualification", isDirectory: true)
            .appendingPathComponent(filename)
    }

    static func decodeReport(_ data: Data) throws -> TranslationQualificationReport {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        return try JSONDecoder().decode(TranslationQualificationReport.self, from: data)
    }

    static var invalid: TranslationQualificationError {
        .invalidReport("frozen adjudication evidence is inconsistent")
    }
}
