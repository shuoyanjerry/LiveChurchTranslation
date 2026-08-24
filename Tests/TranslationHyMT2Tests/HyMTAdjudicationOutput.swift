import TranslationQualificationSupport

enum HyMTAdjudicationOutput {
    static func printEvidence(
        frozen: HyMTAdjudicationFrozenEvidence,
        review: HyMTAdjudicationReviewEvidence,
        expectation: TranslationAttestedReleaseExpectation
    ) throws {
        let binding = try TranslationHumanReviewEvidence.reportBinding(for: frozen.report)
        guard binding == frozen.verifiedFreeze.statement.reportBinding else {
            throw TranslationQualificationError.invalidReport(
                "final adjudication report binding changed"
            )
        }
        print("REPORT_FILE_SHA256=\(frozen.reportSnapshot.sha256)")
        print("CANONICAL_REPORT_BINDING_SHA256=\(binding.reportSHA256)")
        print("POSTFLIGHT_ATTESTATION_SHA256=\(frozen.postflightSnapshot.sha256)")
        print("HUMAN_REVIEW_PACKET_SHA256=\(frozen.reviewPacketSnapshot.sha256)")
        print("FREEZE_ATTESTATION_SHA256=\(expectation.freezeAttestationSHA256)")
        print("FREEZE_AUTHORITY_KEY_ID=\(expectation.freezeAuthorityKeyID)")
        print("REVIEWER_REGISTRY_SHA256=\(review.registrySnapshot.sha256)")
        print("REVIEWER_REGISTRY_ROOT_KEY_ID=\(review.registry.rootKeyID)")
        print("REVIEWER_REGISTRY_REVISION=\(review.registry.registryRevision)")
        print("HUMAN_REVIEW_SIDECAR_SHA256=\(review.settlementSnapshot.sha256)")
        print("RELEASE_READY=true")
    }
}
