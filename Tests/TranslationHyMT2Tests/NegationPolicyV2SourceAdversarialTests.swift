import Testing

@Suite("Negation Policy V2 Mandarin source adversarial cases")
struct NegationPolicyV2SourceAdversarialTests {
    @Test("excluded constructions and known lexical bu forms have no functional count")
    func excludesNonFunctionalConstructions() {
        let sources = [
            "你相信不相信？", "我们不得不祷告。", "我们不能不祷告。",
            "福音不但显明恩典，也显明公义。", "教会不仅传讲，也服事。",
            "不论环境如何，我们仍忠心。", "不管结果怎样，我们仍服事。",
            "不同的恩赐彼此配搭。", "教会不断为城市祷告。", "门徒心里不安。",
        ]

        for source in sources {
            #expect(NegationPolicyV2.sourceDisposition(source) == .noFunctionalNegation)
        }
    }

    @Test("specific phrases and independent bare bu are counted by occurrence")
    func countsFunctionalOccurrences() {
        #expect(
            NegationPolicyV2.sourceDisposition("神没有忘记，也没有离弃。")
                == .requiresOvertCue(count: 2)
        )
        #expect(
            NegationPolicyV2.sourceDisposition("教会不隐藏真理，也不忽略穷人。")
                == .requiresOvertCue(count: 2)
        )
        #expect(
            NegationPolicyV2.sourceDisposition("我们不仅不隐藏真理，也不忽略穷人。")
                == .requiresOvertCue(count: 2)
        )
    }

    @Test("lexical prefix lookalikes do not consume a following functional predicate")
    func respectsChineseLexicalBoundaries() {
        let sources = [
            "他们不同意这项决定。", "讲员不断言臆测的话。", "我们不安排额外聚会。",
            "门徒不论断别人。", "父亲不管教孩子。",
        ]

        for source in sources {
            #expect(
                NegationPolicyV2.sourceDisposition(source) == .requiresOvertCue(count: 1)
            )
        }
    }

    @Test("unknown source cue, scope, and functional questions fail closed to review")
    func routesUnprovableSourceSemanticsToReview() {
        #expect(
            NegationPolicyV2.sourceDisposition("这项安排不妥。")
                == .humanReviewRequired(reason: .unclassifiedSourceCue)
        )
        #expect(
            NegationPolicyV2.sourceDisposition("不是所有听见的人都明白。")
                == .humanReviewRequired(reason: .quantifierScope)
        )
        #expect(
            NegationPolicyV2.sourceDisposition("你不是门徒吗？")
                == .humanReviewRequired(reason: .questionScope(functionalCount: 1))
        )
    }
}
