import TranslationAPI

struct EnglishTheologicalGoldenFixture: Sendable {
    let source: String
    let faithfulChinese: String
    let requiredTerms: [TranslationTerm]
}

enum EnglishTheologicalGoldenFixtures {
    static let grace = term("grace", "恩典")
    static let faith = term("faith", "信心", aliases: ["faith in"])
    static let salvation = term("salvation", "救恩")
    static let justification = term("justification", "称义")
    static let sanctification = term("sanctification", "成圣", accepted: ["圣别"])
    static let redemption = term("redemption", "救赎")
    static let holySpirit = term("Holy Spirit", "圣灵")
    static let resurrection = term("resurrection", "复活")
    static let church = term("church", "教会")
    static let god = term("God", "神")
    static let bodyOfChrist = term("Body of Christ", "基督的身体")
    static let salvationByGraceThroughFaith = term(
        "Salvation is by grace through faith in Jesus Christ",
        "救恩本乎恩典，也因着对耶稣基督的信心"
    )
    static let lovedTheWorld = term("loved the world", "爱世人", accepted: ["爱了世人"])
    static let onlySon = term(
        "His only Son",
        "祂的独生子",
        accepted: ["他的独生子", "独生子"]
    )
    static let glorifyHimself = term(
        "glorify Himself",
        "荣耀自己",
        accepted: ["使自己得荣耀"]
    )
    static let glorifiesChrist = term(
        "He glorifies Christ",
        "祂荣耀基督",
        accepted: [
            "他荣耀基督", "祂荣耀了基督", "他荣耀了基督", "祂使基督得荣耀",
            "他使基督得荣耀", "祂使基督得着荣耀", "他使基督得着荣耀",
        ]
    )
    static let redemptionThroughHisBlood = term(
        "redemption through His blood",
        "借着祂的血得蒙救赎",
        accepted: [
            "借着他的血得蒙救赎", "藉着祂的血得蒙救赎", "藉着他的血得蒙救赎",
            "通过祂的血获得救赎", "透过祂的宝血获得救赎",
        ]
    )
    static let andForgivenessOfSins = term(
        "and the forgiveness of sins",
        "并且罪得赦免",
        accepted: ["就是罪得赦免", "也使罪得赦免", "并得到罪的赦免"]
    )
    static let preaching = term(
        "our preaching",
        "我们的传扬",
        accepted: ["我们的传道", "我们的传讲"]
    )
    static let inVain = term("in vain", "徒然", accepted: ["徒劳", "徒劳无益"])
    static let notByWorks = term(
        "not by works",
        "不是出于行为",
        aliases: ["not from works", "not through works"],
        accepted: [
            "并不是出于行为", "并非出于行为", "不是靠行为", "不靠行为", "不是通过行为",
        ]
    )

    static let accepted = core + extended

    private static let core: [EnglishTheologicalGoldenFixture] = [
        fixture(
            "Salvation is by grace through faith in Jesus Christ, not by works.",
            "救恩本乎恩典，也因着对耶稣基督的信心，不是出于行为。",
            [salvation, grace, faith, salvationByGraceThroughFaith, notByWorks]
        ),
        fixture(
            "John 3:16 declares that God loved the world and gave His only Son.",
            "约翰福音 3:16 讲到神爱世人，并赐下祂的独生子。",
            [god, lovedTheWorld, onlySon]
        ),
        fixture(
            "The Holy Spirit does not glorify Himself; He glorifies Christ.",
            "圣灵不荣耀自己；他荣耀基督。",
            [holySpirit, glorifyHimself, glorifiesChrist]
        ),
        fixture(
            "Justification is God's judicial act, while sanctification transforms our living.",
            "称义是神司法的行动，而成圣改变我们的生活。",
            [justification, sanctification, god]
        ),
        fixture(
            "In Christ we have redemption through His blood and the forgiveness of sins.",
            "我们在基督里，借着他的血得蒙救赎，就是罪得赦免。",
            [redemption, redemptionThroughHisBlood, andForgivenessOfSins]
        ),
        fixture(
            "Without the resurrection, our preaching and our faith would be in vain.",
            "若没有复活，我们的传扬和信心就是徒然的。",
            [resurrection, preaching, faith, inVain]
        ),
        fixture(
            "The church is the Body of Christ, not merely a religious organization.",
            "教会是基督的身体，不仅仅是一个宗教组织。",
            [church, bodyOfChrist]
        ),
        fixture(
            "We worship one God: the Father, the Son, and the Holy Spirit.",
            "我们敬拜一位神：父、子、圣灵。",
            [holySpirit, god]
        ),
    ]

}
