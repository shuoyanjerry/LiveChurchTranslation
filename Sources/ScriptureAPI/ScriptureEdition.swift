public struct ScriptureEdition: Codable, Equatable, Hashable, Sendable {
    public let id: ScriptureEditionID
    public let fullName: String
    public let abbreviation: String
    public let languageTag: String
    public let editionLabel: String
    public let publicationYear: Int
    public let officialEditionReference: String
    public let rightsAdministrator: String

    public init(
        id: ScriptureEditionID,
        fullName: String,
        abbreviation: String,
        languageTag: String,
        editionLabel: String,
        publicationYear: Int,
        officialEditionReference: String,
        rightsAdministrator: String
    ) {
        self.id = id
        self.fullName = fullName
        self.abbreviation = abbreviation
        self.languageTag = languageTag
        self.editionLabel = editionLabel
        self.publicationYear = publicationYear
        self.officialEditionReference = officialEditionReference
        self.rightsAdministrator = rightsAdministrator
    }
}

extension ScriptureEdition {
    public static let englishStandardVersion2025 = Self(
        id: .englishStandardVersion2025,
        fullName: "The Holy Bible, English Standard Version®",
        abbreviation: "ESV",
        languageTag: "en",
        editionLabel: "ESV Text Edition: 2025",
        publicationYear: 2025,
        officialEditionReference: "ESV Text Edition: 2025",
        rightsAdministrator: "Crossway"
    )

    public static let newPunctuationCUVShenSimplified1988 = Self(
        id: .newPunctuationCUVShenSimplified1988,
        fullName: "新标点和合本，神版",
        abbreviation: "CUNPSS-神",
        languageTag: "zh-Hans",
        editionLabel: "1988，简体中文，神版",
        publicationYear: 1988,
        officialEditionReference: "CUNP1s",
        rightsAdministrator: "Hong Kong Bible Society"
    )
}
