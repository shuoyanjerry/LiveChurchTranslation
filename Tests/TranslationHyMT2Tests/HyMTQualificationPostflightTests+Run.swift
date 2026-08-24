import Foundation
import TranslationQualificationSupport

extension HyMTQualificationPostflightTests {
    struct Inputs {
        let corpus: TranslationQualificationCorpus
        let executionGuard: HyMTQualificationExecutionGuard
        let snapshot: HyMTQualificationReportSnapshot
        let provenance: TranslationExecutionProvenance
    }

    func runPostflight(_ configuration: HyMTQualificationConfiguration) throws {
        let inputs = try loadInputs(configuration)
        let sidecarSHA256 = try writePostflightAttestation(
            executionGuard: inputs.executionGuard,
            snapshot: inputs.snapshot,
            corpus: inputs.corpus,
            provenance: inputs.provenance,
            configuration: configuration
        )
        let reviewEvidence = try writeReviewPacket(
            snapshot: inputs.snapshot,
            provenance: inputs.provenance,
            corpus: inputs.corpus,
            sidecarSHA256: sidecarSHA256,
            configuration: configuration
        )
        let freezeRequestSHA256 = try writeFreezeRequest(
            snapshot: inputs.snapshot,
            sidecarSHA256: sidecarSHA256,
            packetSHA256: reviewEvidence.packetSHA256,
            configuration: configuration
        )
        try verifyPostflight(inputs, configuration: configuration)
        printEvidence(
            snapshot: inputs.snapshot,
            sidecarSHA256: sidecarSHA256,
            reviewEvidence: reviewEvidence,
            freezeRequestSHA256: freezeRequestSHA256,
            configuration: configuration
        )
    }

    func loadInputs(_ configuration: HyMTQualificationConfiguration) throws -> Inputs {
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
        let snapshot = try HyMTQualificationReportSnapshot.load(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        let provenance = try executionGuard.finalize(configuration: configuration)
        return Inputs(
            corpus: corpus,
            executionGuard: executionGuard,
            snapshot: snapshot,
            provenance: provenance
        )
    }

    func verifyPostflight(
        _ inputs: Inputs,
        configuration: HyMTQualificationConfiguration
    ) throws {
        try inputs.executionGuard.revalidate(configuration: configuration)
        try inputs.snapshot.requireUnchanged(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
    }

    func printEvidence(
        snapshot: HyMTQualificationReportSnapshot,
        sidecarSHA256: String,
        reviewEvidence: (packetSHA256: String, bindingSHA256: String),
        freezeRequestSHA256: String,
        configuration: HyMTQualificationConfiguration
    ) {
        print("POSTFLIGHT_VERIFIED=true")
        print("REPORT_FILE_SHA256=\(snapshot.sha256)")
        print("CANONICAL_REPORT_BINDING_SHA256=\(reviewEvidence.bindingSHA256)")
        print("POSTFLIGHT_ATTESTATION_SHA256=\(sidecarSHA256)")
        print("HUMAN_REVIEW_PACKET=\(configuration.reviewPacketFilename)")
        print("HUMAN_REVIEW_PACKET_SHA256=\(reviewEvidence.packetSHA256)")
        print("FREEZE_REQUEST=\(configuration.freezeRequestFilename)")
        print("FREEZE_REQUEST_SHA256=\(freezeRequestSHA256)")
    }
}
