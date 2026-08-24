import Foundation
import TranslationAPI

struct HyMT2ValidatedOutput: Equatable, Sendable {
    let target: String
    let pronounRealizations: [HyMT2PronounRealization]
}

enum HyMT2OutputValidator {
    static func validate(
        _ output: String,
        source: String,
        requiredTerms: [TranslationTerm],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        pronounPlan: HyMT2PronounPlan? = nil,
        context: [TranslationContextEntry] = []
    ) throws -> String {
        try validated(
            output,
            source: source,
            requiredTerms: requiredTerms,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            pronounPlan: pronounPlan,
            context: context
        ).target
    }

    static func validated(
        _ output: String,
        source: String,
        requiredTerms: [TranslationTerm],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        pronounPlan: HyMT2PronounPlan?,
        flatRetryCapability: HyMT2FlatPronounRetryCapability? = nil,
        strictRetry: Bool = false,
        context: [TranslationContextEntry] = []
    ) throws -> HyMT2ValidatedOutput {
        let parsed = try parsePronouns(
            output,
            plan: pronounPlan,
            flatRetryCapability: flatRetryCapability,
            strictRetry: strictRetry
        )
        let target = HyMT2TargetOrthographyNormalizer.normalize(
            parsed.cleanTarget,
            language: targetLanguage
        )
        var issues = HyMT2FidelityValidator.issues(
            target: target,
            source: source,
            requiredTerms: requiredTerms,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            context: context
        )
        if rejectsPronounAlternativeList(
            target,
            targetLanguage: targetLanguage,
            plan: pronounPlan
        ) {
            issues.append(.pronounAlternativeList)
        }
        guard issues.isEmpty else {
            throw OutputValidationFailure(
                issues: issues,
                pronounRealizations: parsed.realizations
            )
        }
        return HyMT2ValidatedOutput(
            target: target,
            pronounRealizations: parsed.realizations
        )
    }

    private static func parsePronouns(
        _ output: String,
        plan: HyMT2PronounPlan?,
        flatRetryCapability: HyMT2FlatPronounRetryCapability?,
        strictRetry: Bool
    ) throws -> HyMT2ParsedPronounOutput {
        guard let plan else {
            guard flatRetryCapability == nil else {
                throw OutputValidationFailure(issues: [.malformedPronounMarker])
            }
            return HyMT2ParsedPronounOutput(
                cleanTarget: output.trimmingCharacters(in: .whitespacesAndNewlines),
                realizations: []
            )
        }
        let canonical = HyMT2PronounMarkerTokenizer.tokens(in: output)
        if usesStrictParser(
            output: output,
            canonical: canonical,
            flatRetryCapability: flatRetryCapability,
            strictRetry: strictRetry
        ) {
            return try HyMT2StrictRetryPronounParser.parse(
                output,
                plan: plan,
                flatCapability: flatRetryCapability
            )
        }
        return try HyMT2PronounMarkerParser.parse(output, plan: plan)
    }

    private static func rejectsPronounAlternativeList(
        _ target: String,
        targetLanguage: String,
        plan: HyMT2PronounPlan?
    ) -> Bool {
        plan != nil
            && targetLanguage.lowercased().hasPrefix("en")
            && HyMT2PronounAlternativeListDetector.containsAlternativeList(in: target)
    }

    private static func usesStrictParser(
        output: String,
        canonical: [HyMT2PronounAnchorToken],
        flatRetryCapability: HyMT2FlatPronounRetryCapability?,
        strictRetry: Bool
    ) -> Bool {
        strictRetry || flatRetryCapability != nil
            || HyMT2SpacedCanonicalPronounParser.hasCandidate(canonical, in: output)
    }

}
