import Foundation
import TranslationAPI

enum HyMT2FidelityValidator {
    static func issues(
        target: String,
        source: String,
        requiredTerms: [TranslationTerm],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en",
        context: [TranslationContextEntry] = []
    ) -> [OutputValidationIssue] {
        var issues = structuralIssues(
            target: target,
            source: source,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            context: context
        )
        issues.append(
            contentsOf: preservationIssues(
                target: target,
                source: source,
                requiredTerms: requiredTerms,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            ))
        return issues
    }

    private static func structuralIssues(
        target: String,
        source: String,
        sourceLanguage: String,
        targetLanguage: String,
        context: [TranslationContextEntry]
    ) -> [OutputValidationIssue] {
        var issues: [OutputValidationIssue] = []
        if target.isEmpty { issues.append(.empty) }
        if !plausibleLength(
            target,
            source: source,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            issues.append(.implausibleLength)
        }
        if HyMT2ContextReplayDetector.detect(
            candidateTarget: target,
            recentContext: context
        ) != nil {
            issues.append(.contextReplay)
        }
        if containsMetaText(target) { issues.append(.metaText) }
        let containsPromptControl =
            HyMT2PromptControlDelimiter.occurs(in: target)
            || HyMT2PronounProtocolResidualValidator.containsProtocolFragment(
                in: target,
                plan: nil
            )
        if containsPromptControl {
            issues.append(.promptControlDelimiter)
        }
        if hasUnexpectedScript(target, source: source, targetLanguage: targetLanguage) {
            issues.append(.unexpectedSourceScript)
        }
        return issues
    }

    private static func preservationIssues(
        target: String,
        source: String,
        requiredTerms: [TranslationTerm],
        sourceLanguage: String,
        targetLanguage: String
    ) -> [OutputValidationIssue] {
        var issues = missingTerms(in: target, required: requiredTerms)
        issues.append(contentsOf: missingNumbers(in: target, source: source))
        if HyMT2NegationPreservationValidator.isMissing(
            source: source,
            target: target,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            issues.append(.missingNegation)
        }
        let sourceHasReference = containsScriptureReference(source, language: sourceLanguage)
        if sourceHasReference && !containsScriptureReference(target, language: targetLanguage) {
            issues.append(.malformedScriptureReference)
        }
        return issues
    }
}
