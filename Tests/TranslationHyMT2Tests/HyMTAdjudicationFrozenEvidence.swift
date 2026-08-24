import Foundation
import TranslationQualificationSupport

struct HyMTAdjudicationFrozenEvidence {
    let configuration: HyMTQualificationConfiguration
    let corpus: TranslationQualificationCorpus
    let executionGuard: HyMTQualificationExecutionGuard
    let signedFreezeURL: URL
    let reportSnapshot: HyMTQualificationReportSnapshot
    let freezeSnapshot: HyMTQualificationPrivateSnapshot
    let postflightSnapshot: HyMTQualificationPrivateSnapshot
    let reviewPacketSnapshot: HyMTQualificationPrivateSnapshot
    let verifiedFreeze: TranslationVerifiedFreeze
    let postflight: HyMTQualificationPostflightAttestation
    let report: TranslationQualificationReport
    let files: TranslationFrozenEvidenceFiles

    static func load(_ input: HyMTAdjudicationConfiguration) throws -> Self {
        let configuration = input.qualification
        let execution = try loadExecutionContext(configuration)
        let signedFreeze = try loadSignedFreeze(at: input.signedFreezeURL)
        let artifacts = try loadBoundArtifacts(
            configuration: configuration,
            execution: execution,
            verifiedFreeze: signedFreeze.verified
        )
        return Self(
            configuration: configuration,
            corpus: execution.corpus,
            executionGuard: execution.executionGuard,
            signedFreezeURL: input.signedFreezeURL,
            reportSnapshot: artifacts.reportSnapshot,
            freezeSnapshot: signedFreeze.snapshot,
            postflightSnapshot: artifacts.postflightSnapshot,
            reviewPacketSnapshot: artifacts.reviewPacketSnapshot,
            verifiedFreeze: signedFreeze.verified,
            postflight: artifacts.postflight,
            report: artifacts.report,
            files: artifacts.files
        )
    }

    func requireUnchanged() throws {
        try executionGuard.revalidate(configuration: configuration)
        try reportSnapshot.requireUnchanged(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        _ = try HyMTQualificationPrivateFile.read(
            at: signedFreezeURL,
            expectedSHA256: freezeSnapshot.sha256,
            maximumByteCount: 1_024 * 1_024
        )
        try requirePrivateArtifactUnchanged(
            files.postflightFilename,
            snapshot: postflightSnapshot,
            maximumByteCount: 1_024 * 1_024
        )
        try requirePrivateArtifactUnchanged(
            files.reviewPacketFilename,
            snapshot: reviewPacketSnapshot,
            maximumByteCount: 16 * 1_024 * 1_024
        )
    }
}
