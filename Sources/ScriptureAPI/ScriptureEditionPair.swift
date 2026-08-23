public struct ScriptureEditionPair: Codable, Equatable, Hashable, Sendable {
    public let english: ScriptureEdition
    public let simplifiedChinese: ScriptureEdition

    public init(english: ScriptureEdition, simplifiedChinese: ScriptureEdition) {
        self.english = english
        self.simplifiedChinese = simplifiedChinese
    }

    public static let production = Self(
        english: .englishStandardVersion2025,
        simplifiedChinese: .newPunctuationCUVShenSimplified1988
    )

    public static let terminologyBaselineNotice =
        "These editions define terminology baselines; generated translation is not an exact Bible quotation."

    public static let exactQuotationNotice =
        "Exact quotation requires a licensed, edition-pinned source that passed the private "
        + "rights and hash gate; preserve its wording and glyphs, including 他/祂."
}
