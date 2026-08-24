import TranslationQualificationSupport

enum HyMTQualificationTrustPolicy {
    static let productionFreeze = TranslationFreezeTrustPolicy(
        policyRevision: TranslationQualificationFreezeStatement.currentPolicyRevision,
        authorityPublicKeysByID: [:]
    )
}
