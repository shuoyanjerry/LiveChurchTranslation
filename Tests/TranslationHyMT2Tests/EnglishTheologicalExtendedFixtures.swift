import TranslationAPI

extension EnglishTheologicalGoldenFixtures {
    static let extended: [EnglishTheologicalGoldenFixture] = [
        fixture(
            "Repentance does not purchase forgiveness; it turns the sinner toward God's mercy.",
            "悔改并不能换取赦免；悔改使罪人转向神的怜悯。",
            [repentance, forgiveness, turnsSinnerToward, god, mercy]
        ),
        fixture(
            "The incarnation means that the eternal Son truly took a human nature "
                + "without ceasing to be divine.",
            "道成肉身是指永恒的子真实取得了人性，却没有停止具有神性。",
            [incarnation, humanNature, withoutCeasingDivine]
        ),
        fixture(
            "Baptism does not save by the act itself; it bears witness to union with Christ.",
            "洗礼的行动本身并不能使人得救；它见证人与基督联合。",
            [baptism, unionWithChrist]
        ),
        fixture(
            "At the Lord's Supper the church remembers Christ's death and proclaims His return.",
            "在圣餐中，教会记念基督的死，并宣扬祂的再来。",
            [lordsSupper, church, secondComing]
        ),
        fixture(
            "The covenant promises of God display His faithfulness across generations.",
            "神立约的应许历世历代彰显祂的信实。",
            [godsCovenantPromises, displaysFaithfulness, acrossGenerations]
        ),
        fixture(
            "Jesus Christ is our mediator and the only head of the church.",
            "耶稣基督是我们的中保，也是教会唯一的元首。",
            [jesusChrist, mediator, church, headOfChurch]
        ),
        fixture(
            "The gospel announces forgiveness of sins and eternal life in Christ.",
            "福音宣告在基督里罪得赦免并得着永生。",
            [gospel, lifeAndForgivenessInChrist]
        ),
        fixture(
            "Pastors and elders serve the flock; they do not replace Christ.",
            "牧者和长老服事群羊；他们不能取代基督。",
            [pastors, elders, serveTheFlock, christ]
        ),
        fixture(
            "Spiritual gifts build up the church; they are not given for personal glory.",
            "属灵恩赐为要建造教会；它们并不是为个人荣耀而赐下的。",
            [spiritualGifts, buildUpChurch, personalGlory]
        ),
        fixture(
            "Christian hope rests on Christ's bodily resurrection and promised return.",
            "基督徒的盼望建立在基督身体的复活和祂所应许的再来之上。",
            [christianHope, christBodilyResurrection, promisedReturn]
        ),
        fixture(
            "We pray to the Father through the Son in the Holy Spirit.",
            "我们在圣灵里，借着子向父祷告。",
            [pray, father, throughSon, inHolySpirit]
        ),
        fixture(
            "Grace trains believers to reject sin and to live in holiness.",
            "恩典教导信徒弃绝罪，并活在圣洁中。",
            [grace, believers, holiness]
        ),
        fixture(
            "The LORD is holy, just, merciful, and faithful.",
            "耶和华是圣洁、公义、怜悯并信实的。",
            [lord, holy, just, merciful, faithful]
        ),
        fixture(
            "First Corinthians 15:3-4 was cited without reciting the passage.",
            "讲者引用了哥林多前书 15:3-4，却没有背诵那段经文。",
            [firstCorinthians, wasCited, withoutRecitingPassage]
        ),
        fixture(
            "Romans 8:1 does not erase moral responsibility.",
            "罗马书 8:1 并没有消除道德责任。",
            [romans, moralResponsibility]
        ),
        fixture(
            "In Revelation 21:4, the speaker emphasized Christian hope without quoting the verse.",
            "讲者在启示录 21:4 强调基督徒的盼望，却没有引用那节经文。",
            [revelation, christianHope, withoutQuotingVerse]
        ),
    ]
}

extension EnglishTheologicalGoldenFixtures {
    static let repentance = term("Repentance", "悔改")
    static let forgiveness = term("forgiveness", "赦免", accepted: ["罪得赦免"])
    static let turnsSinnerToward = term("turns the sinner toward", "使罪人转向")
    static let mercy = term("mercy", "怜悯", accepted: ["慈悲"])
    static let incarnation = term("incarnation", "道成肉身")
    static let humanNature = term("human nature", "人性")
    static let withoutCeasingDivine = term(
        "without ceasing to be divine",
        "却没有停止具有神性",
        accepted: ["但并未停止具有神性", "却没有失去神性"]
    )
    static let baptism = term("Baptism", "洗礼")
    static let unionWithChrist = term(
        "union with Christ",
        "与基督联合",
        accepted: ["与基督的联合", "和基督联合", "与基督合一"]
    )
    static let lordsSupper = term("Lord's Supper", "圣餐")
    static let secondComing = term("His return", "祂的再来", accepted: ["他的再来", "基督再来"])
    static let godsCovenantPromises = term(
        "The covenant promises of God",
        "神立约的应许",
        accepted: ["神所立之约的应许"]
    )
    static let displaysFaithfulness = term(
        "display His faithfulness",
        "彰显祂的信实",
        accepted: ["彰显了祂的信实", "显明祂的信实", "彰显其信实", "显明其信实"]
    )
    static let acrossGenerations = term(
        "across generations",
        "在历世历代中",
        accepted: ["历世历代", "世世代代"]
    )
    static let jesusChrist = term("Jesus Christ", "耶稣基督")
    static let mediator = term("mediator", "中保")
    static let headOfChurch = term("head of the church", "教会唯一的元首", accepted: ["教会的元首"])
    static let gospel = term("gospel", "福音")
    static let lifeAndForgivenessInChrist = term(
        "forgiveness of sins and eternal life in Christ",
        "在基督里罪得赦免并得着永生",
        accepted: ["在基督里得蒙赦免并得着永生"]
    )
    static let pastors = term("Pastors", "牧者")
    static let elders = term("elders", "长老")
    static let serveTheFlock = term("serve the flock", "服事群羊", accepted: ["牧养群羊"])
    static let christ = term("Christ", "基督")
    static let spiritualGifts = term("Spiritual gifts", "属灵恩赐")
    static let buildUpChurch = term("build up the church", "建造教会")
    static let personalGlory = term("personal glory", "个人荣耀")
    static let christianHope = term("Christian hope", "基督徒的盼望")
    static let christBodilyResurrection = term(
        "Christ's bodily resurrection",
        "基督身体的复活"
    )
    static let promisedReturn = term("promised return", "应许的再来", accepted: ["所应许的再来"])
    static let pray = term("pray", "祷告")
    static let father = term("Father", "父")
    static let throughSon = term("through the Son", "借着子", accepted: ["藉着子"])
    static let inHolySpirit = term("in the Holy Spirit", "在圣灵里", accepted: ["在圣灵中"])
    static let believers = term("believers", "信徒")
    static let holiness = term("holiness", "圣洁")
    static let lord = term("LORD", "耶和华")
    static let holy = term("holy", "圣洁")
    static let just = term("just", "公义")
    static let merciful = term("merciful", "怜悯", accepted: ["有怜悯"])
    static let faithful = term("faithful", "信实")
    static let firstCorinthians = term("First Corinthians", "哥林多前书")
    static let wasCited = term(
        "was cited",
        "被引用了",
        accepted: ["讲者引用了", "有人引用了"]
    )
    static let withoutRecitingPassage = term(
        "without reciting the passage",
        "没有背诵那段经文",
        accepted: ["没有背诵经文", "未背诵那段经文", "并未背诵那段经文"]
    )
    static let romans = term("Romans", "罗马书")
    static let moralResponsibility = term("moral responsibility", "道德责任")
    static let revelation = term("Revelation", "启示录")
    static let withoutQuotingVerse = term(
        "without quoting the verse",
        "没有引用那节经文",
        accepted: ["没有引用经文", "未引用那节经文", "并未引用那节经文"]
    )
}
