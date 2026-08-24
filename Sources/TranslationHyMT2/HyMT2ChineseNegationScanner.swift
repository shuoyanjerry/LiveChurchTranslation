enum HyMT2ChineseNegationScanner {
    static func requiredCueCount(in source: String) -> Int? {
        guard !ambiguousScopePhrases.contains(where: source.contains),
            !source.contains("？"), !source.contains("?")
        else { return nil }

        let scan = scan(source)
        return scan.unclassifiedCueCount > 0 ? nil : scan.cueOffsets.count
    }

    static func targetCueCount(in target: String) -> Int {
        let scan = scan(target)
        let semantic = countNonoverlapping(semanticTargetPhrases, in: Array(target))
        return scan.cueOffsets.count + scan.unclassifiedCueCount + semantic
    }

    private static func scan(_ text: String) -> Scan {
        let characters = Array(text)
        var masked = Array(repeating: false, count: characters.count)
        var claimed = masked
        maskANotA(in: characters, masked: &masked)
        maskPhrases(excludedPhrases, in: characters, flags: &masked)
        maskPhrases(lexicalPhrases, in: characters, flags: &masked)

        var cues: [Int] = []
        functionalPhrases.forEach {
            claim($0, in: characters, masked: masked, claimed: &claimed, cues: &cues)
        }
        claimBarePredicates(
            in: characters,
            masked: masked,
            claimed: &claimed,
            cues: &cues
        )
        cues.sort()
        let unclassified = characters.indices.filter { index in
            potentialCueCharacters.contains(characters[index])
                && !masked[index] && !claimed[index]
        }.count
        return Scan(cueOffsets: cues, unclassifiedCueCount: unclassified)
    }
}

extension HyMT2ChineseNegationScanner {
    fileprivate static func maskANotA(
        in characters: [Character],
        masked: inout [Bool]
    ) {
        mask("有没有", in: characters, flags: &masked)
        for pivot in characters.indices where characters[pivot] == "不" {
            for width in 1...3 where pivot >= width && pivot + width < characters.count {
                let left = Array(characters[(pivot - width)..<pivot])
                let right = Array(characters[(pivot + 1)...(pivot + width)])
                if left == right {
                    for index in (pivot - width)...(pivot + width) { masked[index] = true }
                    break
                }
            }
        }
    }

    fileprivate static func claimBarePredicates(
        in characters: [Character],
        masked: [Bool],
        claimed: inout [Bool],
        cues: inout [Int]
    ) {
        for index in characters.indices where characters[index] == "不" {
            guard !masked[index], !claimed[index] else { continue }
            let tail = Array(characters[index...])
            guard barePredicatePhrases.contains(where: { tail.starts(with: Array($0)) }) else {
                continue
            }
            claimed[index] = true
            cues.append(index)
        }
    }

    fileprivate static func claim(
        _ phrase: String,
        in characters: [Character],
        masked: [Bool],
        claimed: inout [Bool],
        cues: inout [Int]
    ) {
        for range in ranges(of: phrase, in: characters) {
            guard range.allSatisfy({ !masked[$0] && !claimed[$0] }) else { continue }
            range.forEach { claimed[$0] = true }
            cues.append(range.lowerBound)
        }
    }

    fileprivate static func maskPhrases(
        _ phrases: [String],
        in characters: [Character],
        flags: inout [Bool]
    ) {
        phrases.sorted { $0.count > $1.count }.forEach {
            mask($0, in: characters, flags: &flags)
        }
    }

    fileprivate static func mask(
        _ phrase: String,
        in characters: [Character],
        flags: inout [Bool]
    ) {
        ranges(of: phrase, in: characters).forEach { range in
            range.forEach { flags[$0] = true }
        }
    }

    fileprivate static func ranges(
        of phrase: String,
        in characters: [Character]
    ) -> [Range<Int>] {
        let needle = Array(phrase)
        guard !needle.isEmpty, needle.count <= characters.count else { return [] }
        return (0...(characters.count - needle.count)).compactMap { start in
            let end = start + needle.count
            return Array(characters[start..<end]) == needle ? start..<end : nil
        }
    }

    fileprivate static func countNonoverlapping(
        _ phrases: [String],
        in characters: [Character]
    ) -> Int {
        var claimed = Array(repeating: false, count: characters.count)
        var count = 0
        for phrase in phrases.sorted(by: { $0.count > $1.count }) {
            for range in ranges(of: phrase, in: characters) {
                guard range.allSatisfy({ !claimed[$0] }) else { continue }
                range.forEach { claimed[$0] = true }
                count += 1
            }
        }
        return count
    }
}

extension HyMT2ChineseNegationScanner {
    fileprivate struct Scan {
        let cueOffsets: [Int]
        let unclassifiedCueCount: Int
    }

    fileprivate static let ambiguousScopePhrases = [
        "不是所有", "并非所有", "并非每", "不都", "不一定", "不完全", "不总是",
        "没有一个", "没有任何", "未必",
    ]
    fileprivate static let excludedPhrases = [
        "不得不", "不能不", "不但", "不仅", "不论", "不管", "无论",
    ]
    fileprivate static let lexicalPhrases = [
        "密不可分", "不可一世", "不可预测", "不知不觉", "不安全", "不确定", "不同",
        "不断", "不安", "不凡", "不妨", "不禁", "不久", "不料", "不懈", "不然",
        "不多",
    ]
    fileprivate static let functionalPhrases = [
        "没有", "并非", "不是", "不可", "不能", "不得", "从未", "未曾",
        "绝不", "永不", "毫不", "并不", "尚未",
    ]
    fileprivate static let barePredicatePhrases = [
        "不承认", "不接受", "不安排", "不祷告", "不服事", "不犯罪", "不明白",
        "不遵守", "不离开", "不轻看", "不隐藏", "不忽略", "不高举", "不同意",
        "不断言", "不断定", "不论断", "不管教", "不愿意", "不靠", "不信", "不去",
        "不来", "不说", "不看", "不爱", "不听", "不读", "不在", "不再", "不该",
        "不会", "不必", "不应", "不愿", "不肯", "不需", "不用", "不曾", "不为",
        "不受", "不让", "不叫", "不把", "不被", "不向", "不与",
    ]
    fileprivate static let semanticTargetPhrases = [
        "不仅仅", "缺乏", "缺少", "拒绝", "避免", "免于", "免去", "否认", "禁止",
        "排除", "省略", "免受",
    ]

    fileprivate static let potentialCueCharacters: Set<Character> = ["不", "没", "未", "无", "非"]
}
