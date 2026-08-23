import Foundation

enum ASROutputGuard {
    static func hasPathologicalRepetition(_ text: String) -> Bool {
        let content = text.filter { !$0.isWhitespace && !$0.isPunctuation }
        return hasRepeatedCharacterRun(content) || hasRepeatedPhraseRun(content)
    }

    private static func hasRepeatedCharacterRun(_ text: String) -> Bool {
        var previous: Character?
        var count = 0
        for character in text {
            count = character == previous ? count + 1 : 1
            if count >= 12 { return true }
            previous = character
        }
        return false
    }

    private static func hasRepeatedPhraseRun(_ text: String) -> Bool {
        let characters = Array(text)
        for phraseLength in 2...8 {
            guard characters.count >= phraseLength * 6 else { continue }
            for start in 0...(characters.count - phraseLength * 6) {
                let phrase = characters[start..<(start + phraseLength)]
                let repeated = (1..<6).allSatisfy { repetition in
                    let lower = start + repetition * phraseLength
                    return characters[lower..<(lower + phraseLength)].elementsEqual(phrase)
                }
                if repeated { return true }
            }
        }
        return false
    }
}
