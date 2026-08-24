extension PublicNegationChallengeFixtures {
    /// Public faithful translations that the production guard must not reject.
    static let formerFalseRejects = [
        fixture(
            "single-bare-lexical-paraphrase", "福音不可更改。", "The gospel is immutable.",
            .mustPreserveCount(1)
        ),
        fixture(
            "a-not-a-question", "你信不信这应许？", "Do you believe this promise?",
            .nonFunctional
        ),
        fixture(
            "bu-de-bu-necessity", "我们不得不承认自己的软弱。",
            "We must acknowledge our weakness.", .humanReview
        ),
        fixture(
            "bu-neng-bu-necessity", "我们不能不祷告。", "We must pray.",
            .humanReview
        ),
        fixture(
            "bu-dan-additive", "福音不但显明恩典，也显明公义。",
            "The gospel reveals both grace and righteousness.", .nonFunctional
        ),
        fixture(
            "bu-jin-additive", "教会不仅传讲真理，也活出爱。",
            "The church both proclaims truth and lives out love.", .nonFunctional
        ),
        fixture(
            "bu-lun-concessive", "不论环境如何，我们仍然祷告。",
            "Regardless of the circumstances, we still pray.", .nonFunctional
        ),
        fixture(
            "bu-guan-concessive", "不管结果怎样，我们都忠心服事。",
            "Whatever the outcome, we serve faithfully.", .nonFunctional
        ),
        fixture(
            "bu-tong-lexical", "不同的恩赐建造同一个身体。",
            "Different gifts build up the same body.", .nonFunctional
        ),
        fixture(
            "bu-duan-lexical", "教会不断为这座城祷告。",
            "The church continually prays for this city.", .nonFunctional
        ),
        fixture(
            "bu-an-lexical", "门徒心里不安。", "The disciples were anxious.",
            .nonFunctional
        ),
        fixture(
            "lexical-negative-powerless", "门徒不能靠自己结出属灵的果子。",
            "Self-reliance is powerless to produce spiritual fruit.", .mustPreserveCount(1)
        ),
        fixture(
            "positive-imperative-paraphrase", "不要惧怕，只要信。",
            "Take courage and believe.", .humanReview
        ),
        fixture(
            "lexical-positive-paraphrase", "他没有遵守所作的承诺。",
            "He broke his promise.", .humanReview
        ),
    ]

    private static func fixture(
        _ id: String,
        _ source: String,
        _ target: String,
        _ policy: PublicNegationChallengePolicy
    ) -> PublicNegationChallengeFixture {
        PublicNegationChallengeFixture(
            id: id,
            source: source,
            target: target,
            policy: policy,
            humanOracle: .accept
        )
    }
}
