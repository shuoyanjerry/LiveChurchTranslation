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
        var sections: [String] = []
        if !terms.isEmpty {
            sections.append(termSection(terms))
        }
        sections.append(HyMT2ScripturePolicy.rule(targetLanguage: targetLanguage))
        if strict {
            sections.append(strictRules(targetLanguage: targetLanguage))
        }
        if sourceLanguage.lowercased().hasPrefix("zh") {
            sections.append(HyMT2PronounPrompt.generalRule)
        }
        let recentContext = Array(context.suffix(maximumContextEntries))
        if !recentContext.isEmpty {
            sections.append(
                HyMT2PromptText.backgroundSection(
                    recentContext,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            )
        }
        if let pronounPlan {
            sections.append(HyMT2PronounPrompt.section(pronounPlan.occurrences))
            if strict, let pronounRetryCorrection {
                sections.append(pronounRetryCorrection.section)
            }
        }
        sections.append(
            HyMT2PromptText.currentSourceSection(
                pronounPlan?.protectedSource ?? source,
                targetLanguage: targetLanguage
            )
        )
        return sections.joined(separator: "\n\n")
    }

    private static let maximumContextEntries = 2

    private static func strictRules(targetLanguage: String) -> String {
        var rules = [
            "Translate every clause faithfully without summarizing, adding, or omitting meaning.",
            "Preserve negation, names, and all numbers.",
            "Use required reference terms or an accepted grammatical variant.",
        ]
        if targetLanguage.lowercased().hasPrefix("zh") {
            rules.append(
                "Output Simplified Chinese only; do not use 上帝, traditional Chinese, "
                    + "Japanese, or Korean characters."
            )
            rules.append(
                "For every 'without + action' construction, keep its scope explicit with "
                    + "没有、不、未, or another faithful Chinese negative; never turn the "
                    + "action into a positive clause."
            )
        }
        return rules.joined(separator: " ")
    }

    private static func termSection(_ terms: [TranslationTerm]) -> String {
        let references = terms.map {
            "\(HyMT2PromptText.singleLine($0.source)) translates to "
                + HyMT2PromptText.singleLine($0.target)
        }
        return HyMT2PromptControlDelimiter.glossaryOpening + "\n"
            + references.joined(separator: "\n")
    }
}
