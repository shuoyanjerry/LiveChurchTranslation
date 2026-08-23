import ASRNormalizationAPI
import ASRNormalizationCore
import GlossaryAPI
@testable import SessionManagement
import SettingsAPI
import TranslationAPI

enum ScriptureProductionLanguagePolicy {
    static func asrPrompt(sourceLanguage: String) -> String {
        ASRContextTermSelector.prompt(
            from: DefaultGlossary.entries.filter(\.isEnabled),
            mode: mode(sourceLanguage: sourceLanguage)
        )
    }

    static func normalizedASROutput(_ value: String, sourceLanguage: String) -> String {
        guard mode(sourceLanguage: sourceLanguage) == .mandarinToEnglish else { return value }
        let rules = DefaultGlossary.entries.filter(\.isEnabled).flatMap { entry in
            entry.recognitionAliases.map {
                ASRNormalizationRule(recognitionAlias: $0, canonicalText: entry.source)
            }
        }
        return RuleBasedASRTextNormalizer().normalize(value, using: rules)
    }

    static func translationTerms(
        in source: String,
        sourceLanguage: String
    ) -> [TranslationTerm] {
        let translationMode = mode(sourceLanguage: sourceLanguage)
        let glossary = DefaultGlossary.entries.filter(\.isEnabled).map { entry in
            term(entry, mode: translationMode)
        }.filter { term in
            ([term.source] + term.sourceAliases).contains {
                source.localizedStandardContains($0)
            }
        }
        let scripture = ScriptureBookTermCatalog.matchedTerms(
            in: source,
            mode: translationMode
        )
        return (glossary + scripture).sorted { $0.source.count > $1.source.count }
    }

    private static func term(
        _ entry: GlossaryEntry,
        mode: TranslationMode
    ) -> TranslationTerm {
        switch mode {
        case .mandarinToEnglish:
            TranslationTerm(
                source: entry.source,
                target: entry.target,
                sourceAliases: entry.sourceAliases,
                acceptedTargets: entry.targetVariants,
                requirement: requirement(entry)
            )
        case .englishToSimplifiedChinese:
            TranslationTerm(
                source: entry.target,
                target: entry.source,
                sourceAliases: entry.targetVariants,
                acceptedTargets: entry.sourceAliases,
                requirement: requirement(entry)
            )
        }
    }

    private static func mode(sourceLanguage: String) -> TranslationMode {
        sourceLanguage.lowercased().hasPrefix("zh")
            ? .mandarinToEnglish : .englishToSimplifiedChinese
    }

    private static func requirement(_ entry: GlossaryEntry) -> TranslationTermRequirement {
        entry.enforcement == .required ? .required : .preferred
    }
}
