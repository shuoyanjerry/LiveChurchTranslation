import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationTrustPolicyTests {
    @Test func productionReleaseAuthorityIsFailClosedUntilRealGovernanceExists() {
        #expect(
            HyMTQualificationTrustPolicy.productionFreeze.authorityPublicKeysByID.isEmpty
        )
        #expect(
            TranslationHumanReviewEvidence.productionReviewerRegistryTrustPolicy
                .rootPublicKeysByID.isEmpty
        )
    }
}
