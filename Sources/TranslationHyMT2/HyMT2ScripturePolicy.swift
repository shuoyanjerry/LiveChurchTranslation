import ScriptureAPI

enum HyMT2ScripturePolicy {
    static let editions = ScriptureEditionPair.production

    static func rule(targetLanguage: String) -> String {
        if targetLanguage.lowercased().hasPrefix("zh") {
            return simplifiedChineseRule
        }
        return englishRule
    }

    private static var simplifiedChineseRule: String {
        let edition = editions.simplifiedChinese
        return "Use book names and biblical terminology consistent with "
            + "\(edition.abbreviation), \(edition.fullName) (\(edition.editionLabel); "
            + "official edition reference \(edition.officialEditionReference)). "
            + "Preserve Arabic chapter-and-verse numbers (for example, 约翰福音 3:16), "
            + "use 神 rather than 上帝, allow 他 or 祂 according to context, and never "
            + "reconstruct or invent verse text that the current source did not supply. "
            + "When the current source itself supplies a complete Scripture quotation, "
            + "prefer the established wording of this edition over a loose paraphrase, "
            + "but never add a clause that is absent from the source. "
            + ScriptureEditionPair.terminologyBaselineNotice
    }

    private static var englishRule: String {
        let edition = editions.english
        return "Use book names and biblical terminology consistent with "
            + "\(edition.fullName) (\(edition.abbreviation)), \(edition.editionLabel). "
            + "Preserve conventional numeric references (for example, John 3:16), and never "
            + "reconstruct or invent verse text that the current source did not supply. "
            + "When the current source itself supplies a complete Scripture quotation, "
            + "prefer the established wording of this edition over a loose paraphrase, "
            + "but never add a clause that is absent from the source. "
            + ScriptureEditionPair.terminologyBaselineNotice
    }
}
