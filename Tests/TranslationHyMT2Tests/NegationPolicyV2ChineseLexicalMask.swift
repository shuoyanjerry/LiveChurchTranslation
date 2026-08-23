extension NegationPolicyV2Chinese {
    static func maskLexical(
        _ rule: NegationPolicyV2LexicalRule,
        in characters: [Character],
        flags: inout [Bool]
    ) {
        ranges(of: rule.phrase, in: characters).forEach { range in
            let isFunctionalContinuation =
                range.upperBound < characters.count
                && rule.functionalFollowers.contains(characters[range.upperBound])
            guard !isFunctionalContinuation else { return }
            range.forEach { flags[$0] = true }
        }
    }
}
