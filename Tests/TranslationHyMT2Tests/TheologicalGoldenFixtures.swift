import TranslationAPI

/// Human-authored contract fixtures, not outputs from a model evaluation run.
struct TheologicalGoldenFixture: Sendable {
    let name: String
    let source: String
    let faithfulEnglish: String
    let requiredTerms: [TranslationTerm]
}

enum TheologicalGoldenFixtures {
    static let userRequestedTerms = [
        term("救恩", "salvation"),
        term("恩典", "grace"),
        term("称义", "justification"),
        term("因信称义", "justification by faith"),
        term("成圣", "sanctification"),
        term("重生", "regeneration"),
        term("赎罪", "atonement"),
        term("三位一体", "the Trinity"),
        term("圣灵", "the Holy Spirit"),
        term("团契", "fellowship"),
        term("事奉", "ministry"),
        term("圣餐", "the Lord's Supper"),
        term("洗礼", "baptism"),
    ]

    static let triuneGod = term("三位一体的神", "the triune God")
    static let salvationByGrace = term(
        "救恩本乎恩典，也因着信",
        "salvation is by grace through faith"
    )
    static let contextualTerms = [triuneGod, salvationByGrace]

    static let accepted = [
        TheologicalGoldenFixture(
            name: "soteriology",
            source:
                "救恩并不是出于人的行为，而是出于恩典；称义，尤其是因信称义，"
                + "以及圣灵所施行的重生、基督的赎罪和成圣，都彰显神拯救的恩典。",
            faithfulEnglish:
                "Salvation is not by works but by grace. Justification by faith, "
                + "regeneration by the Holy Spirit, Christ's atonement, and sanctification "
                + "are all works of God's saving grace.",
            requiredTerms: terms(
                "救恩", "恩典", "称义", "因信称义", "成圣", "重生", "赎罪", "圣灵"
            )
        ),
        TheologicalGoldenFixture(
            name: "trinity and church practice",
            source: "三位一体的神借着圣灵，使教会在团契和事奉中，以圣餐和洗礼见证福音。",
            faithfulEnglish:
                "The triune God, through the Holy Spirit, enables the church to bear witness "
                + "to the gospel in fellowship and ministry through the Lord's Supper and baptism.",
            requiredTerms: [triuneGod]
                + terms("圣灵", "团契", "事奉", "圣餐", "洗礼")
        ),
        TheologicalGoldenFixture(
            name: "Ephesians 2:8",
            source: "以弗所书2章8节教导，救恩本乎恩典，也因着信，并不是出于行为。",
            faithfulEnglish:
                "Ephesians 2:8 teaches that salvation is by grace through faith and is not from works.",
            requiredTerms: [salvationByGrace]
        ),
        TheologicalGoldenFixture(
            name: "Matthew 28:19",
            source: "马太福音28章19节命令门徒奉父、子、圣灵的名施行洗礼，不可改变这个命令。",
            faithfulEnglish:
                "Matthew 28:19 commands the disciples to administer baptism in the name of "
                + "the Father, the Son, and the Holy Spirit; this command must not be changed.",
            requiredTerms: terms("圣灵", "洗礼")
        ),
    ]

    static let unrelated = term("大使命", "the Great Commission")

    private static func terms(_ sources: String...) -> [TranslationTerm] {
        sources.compactMap { source in
            userRequestedTerms.first { $0.source == source }
        }
    }

    private static func term(_ source: String, _ target: String) -> TranslationTerm {
        TranslationTerm(source: source, target: target)
    }
}
