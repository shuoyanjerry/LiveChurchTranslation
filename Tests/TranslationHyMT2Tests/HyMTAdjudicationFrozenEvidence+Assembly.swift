import Foundation
import TranslationQualificationSupport

extension HyMTAdjudicationFrozenEvidence {
    struct ExecutionContext {
        let corpus: TranslationQualificationCorpus
        let executionGuard: HyMTQualificationExecutionGuard
        let provenance: TranslationExecutionProvenance
    }

    struct SignedFreeze {
        let snapshot: HyMTQualificationPrivateSnapshot
        let verified: TranslationVerifiedFreeze
    }

    struct BoundArtifacts {
        let reportSnapshot: HyMTQualificationReportSnapshot
        let postflightSnapshot: HyMTQualificationPrivateSnapshot
        let reviewPacketSnapshot: HyMTQualificationPrivateSnapshot
        let postflight: HyMTQualificationPostflightAttestation
        let report: TranslationQualificationReport
        let files: TranslationFrozenEvidenceFiles
    }

    struct LoadedArtifacts {
        let reportSnapshot: HyMTQualificationReportSnapshot
        let report: TranslationQualificationReport
        let postflight:
            (
                snapshot: HyMTQualificationPrivateSnapshot,
                attestation: HyMTQualificationPostflightAttestation
            )
        let packet: HyMTQualificationPrivateSnapshot
    }

    static func loadExecutionContext(
        _ configuration: HyMTQualificationConfiguration
    ) throws -> ExecutionContext {
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )
        let executionGuard = try HyMTQualificationExecutionGuard.begin(
            configuration: configuration,
            corpus: corpus
        )
        let provenance = try executionGuard.finalize(configuration: configuration)
        return ExecutionContext(
            corpus: corpus,
            executionGuard: executionGuard,
            provenance: provenance
        )
    }

    static func loadBoundArtifacts(
        configuration: HyMTQualificationConfiguration,
        execution: ExecutionContext,
        verifiedFreeze: TranslationVerifiedFreeze
    ) throws -> BoundArtifacts {
        let reportSnapshot = try loadReportSnapshot(configuration)
        let report = try decodeReport(reportSnapshot.data)
        let postflight = try loadPostflight(
            configuration: configuration,
            corpus: execution.corpus,
            provenance: execution.provenance,
            reportSnapshot: reportSnapshot,
            expectedSHA256: verifiedFreeze.statement.postflightFileSHA256
        )
        let packet = try privateArtifact(
            configuration.reviewPacketFilename,
            configuration: configuration,
            expectedSHA256: verifiedFreeze.statement.reviewPacketSHA256,
            maximumByteCount: 16 * 1_024 * 1_024
        )
        let loaded = LoadedArtifacts(
            reportSnapshot: reportSnapshot,
            report: report,
            postflight: postflight,
            packet: packet
        )
        return try validateAndAssemble(
            configuration: configuration,
            execution: execution,
            verifiedFreeze: verifiedFreeze,
            loaded: loaded
        )
    }

    static func validateAndAssemble(
        configuration: HyMTQualificationConfiguration,
        execution: ExecutionContext,
        verifiedFreeze: TranslationVerifiedFreeze,
        loaded: LoadedArtifacts
    ) throws -> BoundArtifacts {
        let files = frozenEvidenceFiles(
            configuration: configuration,
            reportSnapshot: loaded.reportSnapshot,
            postflightSnapshot: loaded.postflight.snapshot,
            reviewPacketSnapshot: loaded.packet
        )
        try verifiedFreeze.validateReviewPacket(
            loaded.packet.data,
            report: loaded.report,
            corpus: execution.corpus,
            files: files
        )
        return BoundArtifacts(
            reportSnapshot: loaded.reportSnapshot,
            postflightSnapshot: loaded.postflight.snapshot,
            reviewPacketSnapshot: loaded.packet,
            postflight: loaded.postflight.attestation,
            report: loaded.report,
            files: files
        )
    }

    static func frozenEvidenceFiles(
        configuration: HyMTQualificationConfiguration,
        reportSnapshot: HyMTQualificationReportSnapshot,
        postflightSnapshot: HyMTQualificationPrivateSnapshot,
        reviewPacketSnapshot: HyMTQualificationPrivateSnapshot
    ) -> TranslationFrozenEvidenceFiles {
        TranslationFrozenEvidenceFiles(
            reportFilename: configuration.reportFilename,
            reportFileSHA256: reportSnapshot.sha256,
            postflightFilename: configuration.reportFilename + ".postflight.json",
            postflightFileSHA256: postflightSnapshot.sha256,
            reviewPacketFilename: configuration.reviewPacketFilename,
            reviewPacketSHA256: reviewPacketSnapshot.sha256
        )
    }
}
