import ScriptureAPI

enum ScriptureSettingsPresentation {
    static let editions = ScriptureEditionPair.production

    static var englishBaseline: String {
        let edition = editions.english
        return "\(edition.abbreviation) · \(edition.editionLabel)"
    }

    static var simplifiedChineseBaseline: String {
        let edition = editions.simplifiedChinese
        return "\(edition.abbreviation) · \(edition.fullName) · \(edition.publicationYear)"
    }

    static var notice: String {
        ScriptureEditionPair.terminologyBaselineNotice + " "
            + ScriptureEditionPair.exactQuotationNotice
    }
}
