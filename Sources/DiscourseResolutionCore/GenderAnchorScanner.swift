struct GenderAnchorScanner {
    private struct Term: Sendable {
        let text: String
        let gender: ResolutionGender
    }

    private static let terms: [Term] =
        femaleTerms.map { Term(text: $0, gender: .female) }
        + maleTerms.map { Term(text: $0, gender: .male) }

    private static let femaleTerms = [
        "姊妹", "姐妹", "女孩", "妻子", "太太", "母亲", "妈妈", "女儿", "奶奶",
        "外婆", "新娘", "寡妇", "女士", "女人", "女性",
    ]

    private static let maleTerms = [
        "弟兄", "兄弟", "男孩", "丈夫", "先生", "父亲", "爸爸", "儿子", "爷爷",
        "外公", "新郎", "鳏夫", "男士", "男人", "男性",
    ]

    static func scan(_ text: String) -> [GenderAnchor] {
        var anchors: [GenderAnchor] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard let term = terms.first(where: { text[index...].hasPrefix($0.text) }) else {
                index = text.index(after: index)
                continue
            }
            let upperBound = text.index(index, offsetBy: term.text.count)
            let plural = upperBound < text.endIndex && ["们", "們"].contains(text[upperBound])
            anchors.append(
                GenderAnchor(
                    gender: term.gender,
                    range: index..<upperBound,
                    isPlural: plural
                )
            )
            index = upperBound
        }
        return anchors
    }
}
