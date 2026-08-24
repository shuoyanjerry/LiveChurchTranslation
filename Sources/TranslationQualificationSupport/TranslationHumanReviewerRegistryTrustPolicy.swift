public struct HumanReviewerRegistryTrustPolicy: Equatable, Sendable {
    public let policyRevision: String
    public let registryID: String
    public let registryRevision: Int
    public let rootPublicKeysByID: [String: String]

    public init(
        policyRevision: String,
        registryID: String,
        registryRevision: Int,
        rootPublicKeysByID: [String: String]
    ) {
        self.policyRevision = policyRevision
        self.registryID = registryID
        self.registryRevision = registryRevision
        self.rootPublicKeysByID = rootPublicKeysByID
    }
}

extension TranslationHumanReviewEvidence {
    public static var productionReviewerRegistryTrustPolicy: HumanReviewerRegistryTrustPolicy {
        HumanReviewerRegistryTrustPolicy(
            policyRevision: currentPolicyRevision,
            registryID: "live-church-translation-release-reviewers",
            registryRevision: 1,
            rootPublicKeysByID: [:]
        )
    }
}
