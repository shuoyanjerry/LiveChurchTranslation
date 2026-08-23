enum NegationPolicyV2Chinese {
    static func scan(_ source: String) -> NegationPolicyV2ChineseScan {
        let characters = Array(source)
        var masked = Array(repeating: false, count: characters.count)
        var claimed = masked
        maskANotA(in: characters, masked: &masked)
        exclusions.forEach { mask($0, in: characters, flags: &masked) }
        concessiveExclusions.forEach { mask($0, in: characters, flags: &masked) }
        lexicalExclusions.forEach {
            maskLexical($0, in: characters, flags: &masked)
        }

        var cueOffsets: [Int] = []
        for phrase in functionalPhrases {
            claim(phrase, in: characters, masked: masked, claimed: &claimed, cues: &cueOffsets)
        }
        claimBarePredicates(
            in: characters,
            masked: masked,
            claimed: &claimed,
            cues: &cueOffsets
        )
        cueOffsets.sort()
        let hasUnknown = characters.indices.contains { index in
            potentialCueCharacters.contains(characters[index])
                && !masked[index] && !claimed[index]
        }
        return NegationPolicyV2ChineseScan(
            cueOffsets: cueOffsets,
            clauseCueCounts: clauseCounts(in: characters, cues: cueOffsets),
            hasUnclassifiedCue: hasUnknown
        )
    }

    private static func maskANotA(
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

    private static func claimBarePredicates(
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

    private static func claim(
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

    private static func mask(
        _ phrase: String,
        in characters: [Character],
        flags: inout [Bool]
    ) {
        ranges(of: phrase, in: characters).forEach { range in
            range.forEach { flags[$0] = true }
        }
    }

    static func ranges(
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

    private static func clauseCounts(
        in characters: [Character],
        cues: [Int]
    ) -> [Int] {
        var result: [Int] = []
        var start = 0
        for index in characters.indices where clauseSeparators.contains(characters[index]) {
            if characters[start..<index].contains(where: { !$0.isWhitespace }) {
                result.append(cues.filter { start <= $0 && $0 < index }.count)
            }
            start = index + 1
        }
        let hasTrailingContent =
            start < characters.count
            && characters[start...].contains(where: { !$0.isWhitespace })
        if hasTrailingContent {
            result.append(cues.filter { start <= $0 }.count)
        }
        return result
    }
}
