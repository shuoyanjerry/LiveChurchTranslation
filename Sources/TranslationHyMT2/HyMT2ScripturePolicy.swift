import ScriptureAPI

enum HyMT2ScripturePolicy {
    static let editions = ScriptureEditionPair.production

    static func rule(
        sourceLanguage: String,
        targetLanguage: String
    ) -> String {
        if targetLanguage.lowercased().hasPrefix("zh") {
            return sourceLanguage.lowercased().hasPrefix("zh")
                ? simplifiedChineseRuleChinese : simplifiedChineseRuleEnglish
        }
        return sourceLanguage.lowercased().hasPrefix("zh")
            ? englishRuleChinese : englishRuleEnglish
    }

    private static var simplifiedChineseRuleChinese: String {
        let edition = editions.simplifiedChinese
        return "经文书名和教会术语采用《\(edition.fullName)》（\(edition.abbreviation)）"
            + "的常用表达，使用神而不是上帝；保留章节数字，不补写原文没有的经文。"
    }

    private static var simplifiedChineseRuleEnglish: String {
        let edition = editions.simplifiedChinese
        return "Use natural Simplified Chinese church and Scripture terminology consistent with "
            + "\(edition.fullName) (\(edition.abbreviation)); write 神 rather than 上帝, preserve "
            + "chapter-and-verse numbers, and never add Scripture absent from the source."
    }

    private static var englishRuleChinese: String {
        let edition = editions.english
        return "经文书名和教会术语采用 \(edition.abbreviation) 的自然常用表达；"
            + "保留章节数字，不补写原文没有的经文。"
    }

    private static var englishRuleEnglish: String {
        let edition = editions.english
        return "Use natural church and Scripture terminology consistent with \(edition.abbreviation); "
            + "preserve chapter-and-verse numbers and never add Scripture absent from the source."
    }
}
