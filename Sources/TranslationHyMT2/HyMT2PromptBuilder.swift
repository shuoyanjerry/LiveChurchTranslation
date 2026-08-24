import TranslationAPI

enum HyMT2PromptBuilder {
    static func prompt(
        source: String,
        targetLanguage: String,
        sourceLanguage: String = "zh-Hans",
        terms: [TranslationTerm],
        context: [TranslationContextEntry] = [],
        pronounPlan: HyMT2PronounPlan? = nil,
        pronounRetryCorrection: HyMT2PronounRetryCorrection? = nil,
        strict: Bool
    ) -> String {
        var sections = policySections(
            terms: terms,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            hasPronounPlan: pronounPlan != nil,
            strict: strict
        )
        sections.append(
            contentsOf: backgroundSections(
                context,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            ))
        sections.append(
            contentsOf: pronounSections(
                plan: pronounPlan,
                correction: pronounRetryCorrection,
                strict: strict
            ))
        sections.append(
            HyMT2PromptText.currentSourceSection(
                pronounPlan?.protectedSource ?? source,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        )
        return sections.joined(separator: "\n\n")
    }
}

extension HyMT2PromptBuilder {
    private static let maximumContextEntries = 2

    private static func policySections(
        terms: [TranslationTerm],
        sourceLanguage: String,
        targetLanguage: String,
        hasPronounPlan: Bool,
        strict: Bool
    ) -> [String] {
        var sections: [String] = []
        if !terms.isEmpty {
            sections.append(termSection(terms, sourceLanguage: sourceLanguage))
        }
        sections.append(
            HyMT2ScripturePolicy.rule(
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        )
        if strict {
            sections.append(
                strictRules(
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            )
        }
        if sourceLanguage.lowercased().hasPrefix("zh"), !hasPronounPlan {
            sections.append(HyMT2PronounPrompt.generalRule)
        }
        return sections
    }

    private static func backgroundSections(
        _ context: [TranslationContextEntry],
        sourceLanguage: String,
        targetLanguage: String
    ) -> [String] {
        let recentContext = Array(context.suffix(maximumContextEntries))
        guard !recentContext.isEmpty else { return [] }
        return [
            HyMT2PromptText.backgroundSection(
                recentContext,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        ]
    }

    private static func pronounSections(
        plan: HyMT2PronounPlan?,
        correction: HyMT2PronounRetryCorrection?,
        strict: Bool
    ) -> [String] {
        guard let plan else { return [] }
        var sections = [HyMT2PronounPrompt.section(plan.occurrences)]
        if strict, let correction {
            sections.append(correction.section)
        }
        return sections
    }

    private static func strictRules(
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        if sourceLanguage.lowercased().hasPrefix("zh") {
            return "重译时逐句核对原文，保留所有数字、专名、明确否定和指定术语。"
                + (targetLanguage.lowercased().hasPrefix("zh") ? "" : "只使用目标语言。")
        }
        var rules = [
            "On this retry, preserve every number, name, explicit negation, and required term."
        ]
        if targetLanguage.lowercased().hasPrefix("zh") {
            rules.append(
                "Use Simplified Chinese only, write 神 rather than 上帝, and preserve the scope "
                    + "of every explicit negative construction."
            )
        }
        return rules.joined(separator: " ")
    }

    private static func termSection(
        _ terms: [TranslationTerm],
        sourceLanguage: String
    ) -> String {
        let references = terms.map {
            if sourceLanguage.lowercased().hasPrefix("zh") {
                return "\(HyMT2PromptText.singleLine($0.source)) 翻译成 "
                    + HyMT2PromptText.singleLine($0.target)
            }
            return "\(HyMT2PromptText.singleLine($0.source)) translates to "
                + HyMT2PromptText.singleLine($0.target)
        }
        return HyMT2PromptControlDelimiter.glossaryOpening + "\n"
            + references.joined(separator: "\n")
    }
}
