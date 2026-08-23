import TranslationAPI

extension EnglishTheologicalGoldenFixtures {
    static func term(
        _ source: String,
        _ target: String,
        aliases: [String] = [],
        accepted: [String] = []
    ) -> TranslationTerm {
        TranslationTerm(
            source: source,
            target: target,
            sourceAliases: aliases,
            acceptedTargets: accepted
        )
    }

    static func fixture(
        _ source: String,
        _ target: String,
        _ terms: [TranslationTerm]
    ) -> EnglishTheologicalGoldenFixture {
        EnglishTheologicalGoldenFixture(
            source: source,
            faithfulChinese: target,
            requiredTerms: terms
        )
    }
}
