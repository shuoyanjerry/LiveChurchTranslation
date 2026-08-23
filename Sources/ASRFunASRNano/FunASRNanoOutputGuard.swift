enum FunASRNanoOutputGuard {
    static func hasPathologicalRepetition(_ text: String) -> Bool {
        let compact = text.filter { !$0.isWhitespace && !$0.isPunctuation }
        return containsLongCharacterRun(compact) || containsRepeatedPhrase(compact)
    }

    private static func containsLongCharacterRun(_ text: String) -> Bool {
        var previous: Character?
        var runLength = 0
        for character in text {
            runLength = character == previous ? runLength + 1 : 1
            if runLength >= 12 { return true }
            previous = character
        }
        return false
    }

    private static func containsRepeatedPhrase(_ text: String) -> Bool {
        let characters = Array(text)
        for phraseLength in 2...8 where characters.count >= phraseLength * 6 {
            for start in 0...(characters.count - phraseLength * 6) {
                let phrase = characters[start..<(start + phraseLength)]
                let repeats = (1..<6).allSatisfy { repetition in
                    let lower = start + repetition * phraseLength
                    return characters[lower..<(lower + phraseLength)].elementsEqual(phrase)
                }
                if repeats { return true }
            }
        }
        return false
    }
}
