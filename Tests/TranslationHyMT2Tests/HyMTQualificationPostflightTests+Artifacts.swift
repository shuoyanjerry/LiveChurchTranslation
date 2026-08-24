import Foundation
import TranslationQualificationSupport

extension HyMTQualificationPostflightTests {
    func writePostflightAttestation(
        executionGuard: HyMTQualificationExecutionGuard,
        snapshot: HyMTQualificationReportSnapshot,
        corpus: TranslationQualificationCorpus,
        provenance: TranslationExecutionProvenance,
        configuration: HyMTQualificationConfiguration
    ) throws -> String {
        let attestation = try HyMTQualificationPostflightValidator.validate(
            snapshot: snapshot,
            corpus: corpus,
            provenance: provenance,
            configuration: configuration,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        try executionGuard.revalidate(configuration: configuration)
        try snapshot.requireUnchanged(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        let sidecarURL = try HyMTQualificationPostflightWriter.writePrivate(
            attestation,
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        return try TranslationQualificationSHA256.hash(fileAt: sidecarURL)
    }

    func writeReviewPacket(
        snapshot: HyMTQualificationReportSnapshot,
        provenance: TranslationExecutionProvenance,
        corpus: TranslationQualificationCorpus,
        sidecarSHA256: String,
        configuration: HyMTQualificationConfiguration
    ) throws -> (packetSHA256: String, bindingSHA256: String) {
        let report = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: snapshot.data
        )
        let expectation = try TranslationReleaseExpectation(
            trustedExecutionProvenance: provenance,
            corpus: corpus,
            provider: report.provider,
            environment: report.environment,
            attempts: report.attempts
        )
        let packet = try TranslationHumanReviewEvidence.makeReviewPacket(
            report: report,
            expectation: expectation,
            reportFileSHA256: snapshot.sha256,
            postflightFileSHA256: sidecarSHA256
        )
        let packetURL = try TranslationHumanReviewEvidence.writePrivateReviewPacket(
            packet,
            workspaceRoot: configuration.workspaceRoot,
            filename: configuration.reviewPacketFilename
        )
        let packetSHA256 = try TranslationQualificationSHA256.hash(fileAt: packetURL)
        let bindingSHA256 = try TranslationHumanReviewEvidence.reportBinding(for: report).reportSHA256
        return (packetSHA256, bindingSHA256)
    }

    func writeFreezeRequest(
        snapshot: HyMTQualificationReportSnapshot,
        sidecarSHA256: String,
        packetSHA256: String,
        configuration: HyMTQualificationConfiguration
    ) throws -> String {
        let report = try JSONDecoder().decode(
            TranslationQualificationReport.self,
            from: snapshot.data
        )
        let statement = try TranslationQualificationFreezeEvidence.makeStatement(
            report: report,
            artifacts: TranslationFreezeArtifactIdentity(
                reportFilename: configuration.reportFilename,
                reportSHA256: snapshot.sha256,
                postflightFilename: configuration.reportFilename + ".postflight.json",
                postflightSHA256: sidecarSHA256,
                reviewPacketFilename: configuration.reviewPacketFilename,
                reviewPacketSHA256: packetSHA256
            ),
            frozenAt: ISO8601DateFormatter().string(from: Date())
        )
        let data = try TranslationQualificationFreezeEvidence.encodeStatement(statement)
        let url = try HyMTQualificationPostflightWriter.writePrivate(
            data,
            workspaceRoot: configuration.workspaceRoot,
            filename: configuration.freezeRequestFilename
        )
        return try TranslationQualificationSHA256.hash(fileAt: url)
    }
}
