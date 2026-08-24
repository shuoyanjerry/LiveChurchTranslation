import Foundation

extension TranslationHumanReviewEvidence {
    public static func encodeReviewerRegistry(
        _ registry: TranslationHumanReviewerRegistry
    ) throws -> Data {
        try HumanReviewerRegistryValidator.validateEnvelope(registry)
        return try canonicalData(registry)
    }

    public static func decodeUntrustedReviewerRegistry(
        from data: Data
    ) throws -> TranslationHumanReviewerRegistry {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        let registry: TranslationHumanReviewerRegistry
        do {
            registry = try JSONDecoder().decode(
                TranslationHumanReviewerRegistry.self,
                from: data
            )
        } catch let error as TranslationQualificationError {
            throw error
        } catch {
            throw TranslationQualificationError.invalidJSON(
                "human reviewer registry does not match its strict schema"
            )
        }
        try HumanReviewerRegistryValidator.validateEnvelope(registry)
        guard data == (try canonicalData(registry)) else {
            throw TranslationQualificationError.invalidReport(
                "human reviewer registry is not canonical"
            )
        }
        return registry
    }

    public static func verifyReviewerRegistry(
        from data: Data,
        trustPolicy: HumanReviewerRegistryTrustPolicy
    ) throws -> TranslationHumanReviewerRegistry {
        let registry = try decodeUntrustedReviewerRegistry(from: data)
        try HumanReviewerRegistryValidator.verify(registry, trustPolicy: trustPolicy)
        return registry
    }

    public static func decodeProductionReviewerRegistry(
        from data: Data
    ) throws -> TranslationHumanReviewerRegistry {
        try verifyReviewerRegistry(
            from: data,
            trustPolicy: productionReviewerRegistryTrustPolicy
        )
    }
}
