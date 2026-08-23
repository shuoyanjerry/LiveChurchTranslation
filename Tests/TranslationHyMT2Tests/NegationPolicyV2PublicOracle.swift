struct NegationPolicyV2OracleCase: Sendable {
    let challengeID: String
    let expected: NegationPolicyV2Disposition
}

enum NegationPolicyV2PublicOracle {
    /// Independent, human-authored expectations; never derived from the current validator.
    static let cases = [
        oracle(
            "single-bare-negation-scope-shift",
            .humanReviewRequired(reason: .mixedPolarityClauses(functionalCount: 1))
        ),
        oracle(
            "two-independent-negations-one-lost",
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 2, observed: 1))
        ),
        oracle(
            "three-independent-negations-two-lost",
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 3, observed: 1))
        ),
        oracle(
            "quantifier-scope-not-all-to-none",
            .humanReviewRequired(reason: .quantifierScope)
        ),
        oracle(
            "single-bare-lexical-paraphrase",
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 1, observed: 0))
        ),
        oracle("a-not-a-question", .noFunctionalNegation),
        oracle("bu-de-bu-necessity", .noFunctionalNegation),
        oracle("bu-neng-bu-necessity", .noFunctionalNegation),
        oracle("bu-dan-additive", .noFunctionalNegation),
        oracle("bu-jin-additive", .noFunctionalNegation),
        oracle("bu-lun-concessive", .noFunctionalNegation),
        oracle("bu-guan-concessive", .noFunctionalNegation),
        oracle("bu-tong-lexical", .noFunctionalNegation),
        oracle("bu-duan-lexical", .noFunctionalNegation),
        oracle("bu-an-lexical", .noFunctionalNegation),
        oracle(
            "lexical-negative-powerless",
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 1, observed: 0))
        ),
        oracle(
            "positive-imperative-paraphrase",
            .humanReviewRequired(reason: .mixedPolarityClauses(functionalCount: 1))
        ),
        oracle(
            "lexical-positive-paraphrase",
            .humanReviewRequired(reason: .targetCueCountMismatch(expected: 1, observed: 0))
        ),
    ]

    private static func oracle(
        _ challengeID: String,
        _ expected: NegationPolicyV2Disposition
    ) -> NegationPolicyV2OracleCase {
        NegationPolicyV2OracleCase(challengeID: challengeID, expected: expected)
    }
}
