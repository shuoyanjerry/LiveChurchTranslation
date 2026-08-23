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
        pronounPlan: HyMT2PronounPlan? = nil
    ) throws -> String {
        try validated(
            output,
            source: source,
            requiredTerms: requiredTerms,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            pronounPlan: pronounPlan
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
        strictRetry: Bool = false
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
        let issues = HyMT2FidelityValidator.issues(
            target: target,
            source: source,
            requiredTerms: requiredTerms,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        guard issues.isEmpty else { throw OutputValidationFailure(issues: issues) }
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
        if strictRetry || flatRetryCapability != nil {
            return try HyMT2StrictRetryPronounParser.parse(
                output,
                plan: plan,
                flatCapability: flatRetryCapability
            )
        }
        return try HyMT2PronounMarkerParser.parse(output, plan: plan)
    }

}
