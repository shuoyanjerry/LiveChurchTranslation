import ASRNormalizationAPI

public struct RuleBasedASRTextNormalizer: ASRTextNormalizer {
    public init() {}

    public func normalize(
        _ text: String,
        using additionalRules: [ASRNormalizationRule]
    ) -> String {
        guard !text.isEmpty else { return text }
        let rules = compile(additionalRules + BuiltInASRNormalizationRules.rules)
        guard !rules.isEmpty else { return text }
        return replacingMatches(in: text, with: rules)
    }

    private func compile(_ rules: [ASRNormalizationRule]) -> [CompiledRule] {
        var aliases = Set<String>()
        let valid = rules.enumerated().compactMap { order, rule -> CompiledRule? in
            let alias = trim(rule.recognitionAlias)
            let canonical = trim(rule.canonicalText)
            guard
                !alias.isEmpty,
                !canonical.isEmpty,
                alias != canonical,
                aliases.insert(alias).inserted
            else { return nil }
            return CompiledRule(alias: alias, canonical: canonical, order: order)
        }
        return valid.sorted {
            if $0.alias.count == $1.alias.count { return $0.order < $1.order }
            return $0.alias.count > $1.alias.count
        }
    }

    private func replacingMatches(
        in text: String,
        with rules: [CompiledRule]
    ) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var cursor = text.startIndex
        while cursor < text.endIndex {
            let suffix = text[cursor...]
            if let match = rules.first(where: { suffix.hasPrefix($0.alias) }) {
                result.append(match.canonical)
                cursor = text.index(cursor, offsetBy: match.alias.count)
            } else {
                result.append(text[cursor])
                cursor = text.index(after: cursor)
            }
        }
        return result
    }

    private func trim(_ text: String) -> String {
        let leadingTrimmed = text.drop(while: { $0.isWhitespace })
        return String(leadingTrimmed.reversed().drop(while: { $0.isWhitespace }).reversed())
    }
}

private struct CompiledRule {
    let alias: String
    let canonical: String
    let order: Int
}
