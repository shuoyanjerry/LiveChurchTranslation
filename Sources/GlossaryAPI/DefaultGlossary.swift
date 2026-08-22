public enum DefaultGlossary {
    public static let entries = scriptureAndDoctrineEntries + ministryEntries
}

extension DefaultGlossary {
    fileprivate static let scriptureAndDoctrineEntries: [GlossaryEntry] = [
        GlossaryEntry(source: "你们要去，使万民作我的门徒", target: "go and make disciples of all nations"),
        GlossaryEntry(source: "你们得救是本乎恩，也因着信", target: "by grace you have been saved through faith"),
        GlossaryEntry(
            source: "救恩本乎恩典，也因着信",
            target: "salvation is by grace through faith"),
        GlossaryEntry(
            source: "太初有道，道与神同在，道就是神",
            target: "In the beginning was the Word, and the Word was with God, and the Word was God"),
        GlossaryEntry(
            source: "奉父、子、圣灵的名", target: "in the name of the Father and of the Son and of the Holy Spirit"),
        GlossaryEntry(source: "主耶稣基督", target: "the Lord Jesus Christ"),
        GlossaryEntry(source: "罪得赦免", target: "the forgiveness of sins"),
        GlossaryEntry(source: "与基督联合", target: "union with Christ"),
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
        GlossaryEntry(source: "本乎恩因着信", target: "by grace through faith"),
        GlossaryEntry(source: "惟独藉着信心", target: "through faith alone"),
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

extension DefaultGlossary {
    fileprivate static let ministryEntries: [GlossaryEntry] = [
        GlossaryEntry(source: "圣灵", target: "the Holy Spirit", enforcement: .required),
        GlossaryEntry(source: "圣父", target: "God the Father"),
        GlossaryEntry(source: "圣子", target: "God the Son"),
        GlossaryEntry(
            source: "救恩",
            target: "salvation",
            recognitionAliases: ["休恩"],
            targetVariants: ["saved", "saving"],
            enforcement: .required),
        GlossaryEntry(source: "恩典", target: "grace", enforcement: .required),
        GlossaryEntry(
            source: "称义",
            target: "justification",
            targetVariants: ["justified", "justify", "justifies"]),
        GlossaryEntry(
            source: "在圣灵里成圣",
            target: "be sanctified in the Holy Spirit"),
        GlossaryEntry(
            source: "成圣",
            target: "sanctification",
            targetVariants: ["sanctified", "sanctify", "sanctifies"]),
        GlossaryEntry(
            source: "重生",
            target: "regeneration",
            targetVariants: ["born again", "new birth"]),
        GlossaryEntry(source: "赎罪", target: "atonement", enforcement: .required),
        GlossaryEntry(source: "悔改", target: "repentance"),
        GlossaryEntry(source: "信心", target: "faith"),
        GlossaryEntry(source: "罪性", target: "sinful nature"),
        GlossaryEntry(source: "原罪", target: "original sin"),
        GlossaryEntry(source: "十字架", target: "the cross"),
        GlossaryEntry(source: "复活", target: "resurrection"),
        GlossaryEntry(source: "永生", target: "eternal life"),
        GlossaryEntry(source: "福音", target: "the gospel"),
        GlossaryEntry(source: "圣经", target: "Scripture"),
        GlossaryEntry(source: "耶稣基督", target: "Jesus Christ"),
        GlossaryEntry(source: "独生子", target: "the one and only Son"),
        GlossaryEntry(source: "教会", target: "the church"),
        GlossaryEntry(source: "门徒", target: "disciple"),
        GlossaryEntry(source: "使徒", target: "apostle"),
        GlossaryEntry(source: "先知", target: "prophet"),
        GlossaryEntry(source: "牧者", target: "pastor"),
        GlossaryEntry(source: "长老", target: "elder"),
        GlossaryEntry(source: "执事", target: "deacon"),
        GlossaryEntry(source: "敬拜", target: "worship"),
        GlossaryEntry(source: "祷告", target: "prayer"),
        GlossaryEntry(source: "见证", target: "testimony"),
        GlossaryEntry(source: "律法", target: "the law"),
        GlossaryEntry(source: "盟约", target: "covenant"),
        GlossaryEntry(source: "应许", target: "promise"),
        GlossaryEntry(source: "拣选", target: "election"),
        GlossaryEntry(source: "预定", target: "predestination"),
        GlossaryEntry(source: "属灵恩赐", target: "spiritual gift"),
        GlossaryEntry(source: "方言", target: "tongues"),
        GlossaryEntry(source: "宝血", target: "the blood of Christ"),
        GlossaryEntry(source: "属灵", target: "spiritual"),
        GlossaryEntry(source: "肢体", target: "fellow member of the body of Christ"),
        GlossaryEntry(source: "再来", target: "the Second Coming"),
        GlossaryEntry(source: "末世", target: "the last days"),
        GlossaryEntry(source: "团契", target: "fellowship"),
        GlossaryEntry(
            source: "事奉",
            target: "ministry",
            targetVariants: ["serve", "serving", "service"]),
        GlossaryEntry(
            source: "圣餐",
            target: "the Lord's Supper",
            targetVariants: ["Holy Communion", "Communion"],
            enforcement: .required),
        GlossaryEntry(
            source: "洗礼",
            target: "baptism",
            sourceAliases: ["受浸"],
            targetVariants: ["baptized", "baptize"]),
    ]
}
