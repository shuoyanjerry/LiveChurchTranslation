import Foundation
import TranslationAPI

enum HyMT2FidelityValidator {
    static func issues(
        target: String,
        source: String,
        requiredTerms: [TranslationTerm],
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) -> [OutputValidationIssue] {
        var issues: [OutputValidationIssue] = []
        if target.isEmpty { issues.append(.empty) }
        if !plausibleLength(target, source: source) { issues.append(.implausibleLength) }
        if containsMetaText(target) { issues.append(.metaText) }
        if HyMT2PromptControlDelimiter.occurs(in: target) {
            issues.append(.promptControlDelimiter)
        }
        if hasUnexpectedScript(target, source: source, targetLanguage: targetLanguage) {
            issues.append(.unexpectedSourceScript)
        }
        issues.append(contentsOf: missingTerms(in: target, required: requiredTerms))
        issues.append(contentsOf: missingNumbers(in: target, source: source))
        let sourceHasNegation = containsNegation(source, language: sourceLanguage)
        if sourceHasNegation && !containsNegation(target, language: targetLanguage) {
            issues.append(.missingNegation)
        }
        let sourceHasReference = containsScriptureReference(source, language: sourceLanguage)
        if sourceHasReference && !containsScriptureReference(target, language: targetLanguage) {
            issues.append(.malformedScriptureReference)
        }
        return issues
    }
}
