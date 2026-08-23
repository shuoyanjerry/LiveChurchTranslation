import Testing

@Suite("Hy-MT2 negation cue classifier")
struct HyMTNegationCueClassifierTests {
    @Test func distinguishesSpecificCompoundAndTokenizerStandaloneCues() {
        #expect(
            HyMTNegationCueClassifier.sourceClasses("恩典没有失效。") == [.specificPhrase]
        )
        #expect(
            HyMTNegationCueClassifier.sourceClasses("工作不可停止。") == [.compoundBu]
        )
        #expect(
            HyMTNegationCueClassifier.sourceClasses("我们 不 惧怕。").contains(.standaloneBu)
        )
        #expect(HyMTNegationCueClassifier.sourceClasses("恩典临到。") == [.none])
    }

    @Test func distinguishesExplicitLexicalAndAbsentEnglishCues() {
        #expect(HyMTNegationCueClassifier.targetClass("It cannot fail.") == .explicit)
        #expect(HyMTNegationCueClassifier.targetClass("It isn’t lost.") == .explicit)
        #expect(HyMTNegationCueClassifier.targetClass("Stopping is forbidden.") == .lexical)
        #expect(HyMTNegationCueClassifier.targetClass("The work continues.") == .none)
    }
}
