extension PublicNegationChallengeFixtures {
    /// Public, human-authored examples whose English is deliberately unfaithful.
    static let falsePasses = [
        PublicNegationChallengeFixture(
            id: "single-bare-negation-scope-shift",
            source: "这位弟兄不离开，他继续服事。",
            target: "This brother leaves, but he does not stop serving.",
            policy: .humanReview,
            humanOracle: .reject
        ),
        PublicNegationChallengeFixture(
            id: "two-independent-negations-one-lost",
            source: "我们不靠行为得救，也不轻看悔改。",
            target: "We are not saved by works, and we treat repentance lightly.",
            policy: .mustPreserveCount(2),
            humanOracle: .reject
        ),
        PublicNegationChallengeFixture(
            id: "three-independent-negations-two-lost",
            source: "教会不隐藏真理，不忽略穷人，也不高举自己。",
            target: "The church does not hide the truth, ignores the poor, and exalts itself.",
            policy: .mustPreserveCount(3),
            humanOracle: .reject
        ),
        PublicNegationChallengeFixture(
            id: "quantifier-scope-not-all-to-none",
            source: "不是所有听见的人都明白。",
            target: "No one who hears understands.",
            policy: .humanReview,
            humanOracle: .reject
        ),
    ]
}
