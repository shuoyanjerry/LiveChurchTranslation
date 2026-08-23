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
        "以上版本只用于统一圣经术语；自动生成的翻译不是圣经逐字引文。"
            + "精确引用必须使用测试者提供、已锁定版本且通过来源与哈希校验的文本，"
            + "并原样保留用词和字形，包括“他／祂”。"
    }
}
