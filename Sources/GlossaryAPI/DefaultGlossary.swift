public enum DefaultGlossary {
    public static let entries = scriptureAndDoctrineEntries + ministryEntries + relationEntries
}

extension DefaultGlossary {
    fileprivate static let scriptureAndDoctrineEntries: [GlossaryEntry] = [
        GlossaryEntry(source: "主耶稣基督", target: "the Lord Jesus Christ"),
        GlossaryEntry(source: "神", target: "God", enforcement: .required),
        GlossaryEntry(
            source: "耶和华",
            target: "the LORD",
            targetVariants: ["LORD"],
            enforcement: .required),
        GlossaryEntry(source: "罪得赦免", target: "the forgiveness of sins"),
        GlossaryEntry(
            source: "在基督里罪得赦免并得着永生",
            target: "forgiveness of sins and eternal life in Christ",
            sourceAliases: ["在基督里得蒙赦免并得着永生"],
            enforcement: .required),
        GlossaryEntry(
            source: "与基督联合",
            target: "union with Christ",
            sourceAliases: ["与基督的联合", "和基督联合", "与基督合一"]),
        GlossaryEntry(source: "基督的身体", target: "the body of Christ"),
        GlossaryEntry(source: "大使命", target: "the Great Commission"),
        GlossaryEntry(source: "神的国", target: "the kingdom of God"),
        GlossaryEntry(source: "天国", target: "the kingdom of heaven"),
        GlossaryEntry(source: "新造的人", target: "a new creation"),
        GlossaryEntry(source: "唯独圣经", target: "Scripture alone"),
        GlossaryEntry(source: "唯独恩典", target: "grace alone"),
        GlossaryEntry(source: "唯独信心", target: "faith alone"),
        GlossaryEntry(source: "唯独基督", target: "Christ alone"),
        GlossaryEntry(source: "荣耀唯独归于神", target: "glory to God alone"),
        GlossaryEntry(
            source: "因信称义",
            target: "justification by faith",
            recognitionAliases: ["因信生义"],
            targetVariants: ["justified by faith", "justification through faith"],
            enforcement: .required),
        GlossaryEntry(source: "本乎恩典，因着信心", target: "by grace through faith"),
        GlossaryEntry(
            source: "并不是出于行为",
            target: "not by works",
            sourceAliases: ["不是出于行为", "不靠行为", "不是通过行为"],
            targetVariants: ["not from works", "not through works"],
            enforcement: .required),
        GlossaryEntry(source: "惟独藉着信心", target: "through faith alone"),
        GlossaryEntry(
            source: "爱世人",
            target: "loved the world",
            targetVariants: ["love the world"]),
        GlossaryEntry(
            source: "独生子",
            target: "only Son",
            targetVariants: ["His only Son", "only begotten Son"]),
        GlossaryEntry(
            source: "三位一体的神",
            target: "the triune God",
            targetVariants: ["the Trinitarian God"],
            enforcement: .required),
        GlossaryEntry(
            source: "三位一体",
            target: "the Trinity",
            targetVariants: ["Trinitarian"],
            enforcement: .required),
        GlossaryEntry(source: "圣父、圣子、圣灵", target: "the Father, the Son, and the Holy Spirit"),
        GlossaryEntry(source: "道成肉身", target: "the incarnation"),
        GlossaryEntry(source: "神人二性", target: "the divine and human natures"),
        GlossaryEntry(source: "代赎", target: "substitutionary atonement"),
        GlossaryEntry(source: "刑罚代赎", target: "penal substitutionary atonement"),
        GlossaryEntry(source: "挽回祭", target: "propitiation"),
        GlossaryEntry(source: "施恩座", target: "the mercy seat"),
        GlossaryEntry(source: "中保", target: "mediator"),
        GlossaryEntry(source: "全然败坏", target: "total depravity"),
        GlossaryEntry(source: "无条件拣选", target: "unconditional election"),
        GlossaryEntry(source: "圣徒蒙保守", target: "the perseverance of the saints"),
    ]
}
