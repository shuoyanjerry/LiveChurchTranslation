extension NegationPolicyV2Chinese {
    static let exclusions = [
        "不得不", "不能不", "不但", "不仅",
    ]
    static let concessiveExclusions = [
        "不论环境", "不论结果", "不论如何", "不论怎样", "不论什么", "不论谁", "不论是否",
        "不管环境", "不管结果", "不管如何", "不管怎样", "不管什么", "不管谁", "不管是否",
        "无论环境", "无论结果", "无论如何", "无论怎样", "无论什么", "无论谁", "无论是否",
    ]
    static let lexicalExclusions = [
        NegationPolicyV2LexicalRule("不同", functionalFollowers: ["意"]),
        NegationPolicyV2LexicalRule("不断", functionalFollowers: ["言", "定"]),
        NegationPolicyV2LexicalRule("不安", functionalFollowers: ["排"]),
        NegationPolicyV2LexicalRule("不凡"),
        NegationPolicyV2LexicalRule("不妨"),
        NegationPolicyV2LexicalRule("不禁"),
        NegationPolicyV2LexicalRule("不久"),
        NegationPolicyV2LexicalRule("不料"),
        NegationPolicyV2LexicalRule("不懈"),
        NegationPolicyV2LexicalRule("不然"),
    ]
    static let functionalPhrases = [
        "没有", "并非", "不是", "不可", "不能", "不要", "不得", "从未", "未曾",
        "绝不", "永不", "毫不", "并不", "尚未",
    ]
    static let barePredicatePhrases = [
        "不承认", "不接受", "不安排", "不祷告", "不服事", "不犯罪", "不明白",
        "不遵守", "不离开", "不轻看", "不隐藏", "不忽略", "不高举", "不同意",
        "不断言", "不断定", "不论断", "不管教", "不靠", "不信", "不去", "不来",
        "不说", "不看", "不爱", "不听", "不读",
    ]
    static let potentialCueCharacters: Set<Character> = ["不", "没", "未", "无", "非"]
    static let clauseSeparators: Set<Character> = ["，", ",", "；", ";", "。", "！", "!", "？", "?"]
}

struct NegationPolicyV2LexicalRule: Sendable {
    let phrase: String
    let functionalFollowers: Set<Character>

    init(_ phrase: String, functionalFollowers: Set<Character> = []) {
        self.phrase = phrase
        self.functionalFollowers = functionalFollowers
    }
}
