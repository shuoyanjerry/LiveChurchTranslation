struct HyMT2SchemaShadowPronounFixture: Sendable {
    let base: PublicPronounFixture
    let occurrenceAnchorAlternatives: [[String]]
    let globalAnchorGroups: [[String]]
}

enum HyMT2SchemaShadowFixtures {
    static let negation = [
        existing("one.not"),
        existing("two.no.never"),
        existing("three.not.cannot.no"),
        challenge,
    ]

    static let pronoun: [HyMT2SchemaShadowPronounFixture] = [
        pronounValue(0, [["share", "testimon", "continued"]], [["share"], ["testimon"]]),
        pronounValue(
            1, [["son", "gave", "sent"]],
            [["god"], ["love"], ["world"], ["son"]]
        ),
        pronounValue(
            2,
            [
                ["hong kong", "hong"], ["relative", "family", "singapore"],
                ["english", "knew", "know"], ["communicat", "talk", "speak"],
            ],
            [["hong"], ["singapore"], ["english"], ["communicat", "talk", "speak"]]
        ),
        pronounValue(
            3, [["said", "help"], ["help"], ["family"]],
            [["sister"], ["help"], ["pray"], ["family"]]
        ),
        pronounValue(
            4, [["testimon", "witness"], ["respond", "answer"]],
            [["testimon", "witness"], ["respond", "answer"]]
        ),
        pronounValue(
            5, [["comfort"], ["respond", "answer"]],
            [["god"], ["grace"], ["brother"], ["comfort"]]
        ),
        pronounValue(
            6, [["pray"], ["read", "scripture", "bible"]],
            [["brother"], ["pray"], ["read", "scripture", "bible"]]
        ),
        pronounValue(
            7, [["pray"], ["bible", "scripture"], ["return", "gave", "give"]],
            [["sister"], ["pray"], ["bible", "scripture"]]
        ),
        pronounValue(
            8, [["comfort"], ["comfort"]],
            [["brother"], ["thank"], ["god"], ["comfort"]]
        ),
    ]

    private static func existing(_ identifier: String) -> HyMT2NegationShadowQ4Fixture {
        guard
            let fixture = HyMT2NegationShadowQ4Fixtures.all.first(where: {
                $0.identifier == identifier
            })
        else {
            preconditionFailure("Static public negation fixture is missing.")
        }
        return fixture
    }

    private static let challenge = HyMT2NegationShadowQ4Fixture(
        identifier: "challenge.three.scope",
        base: HyMT2NegationShadowFixture(
            name: "challenge-three-scope",
            source: "教会不隐藏真理，不忽略穷人，也不高举自己。",
            functionalCues: (0..<3).map {
                HyMT2NegationShadowCueReference(text: "不", occurrence: $0)
            }
        ),
        occurrenceAnchorAlternatives: [
            ["hide", "conceal"], ["poor", "needy"], ["exalt", "elevat", "glorif"],
        ],
        globalAnchorGroups: [
            ["church"], ["truth"], ["poor", "needy"], ["itself", "self"],
        ]
    )

    private static func pronounValue(
        _ index: Int,
        _ occurrenceAnchors: [[String]],
        _ globalAnchors: [[String]]
    ) -> HyMT2SchemaShadowPronounFixture {
        let fixture = HyMT2PublicPronounFixtures.all[index]
        precondition(
            fixture.references.count == occurrenceAnchors.count,
            "Static public pronoun anchor mismatch."
        )
        return HyMT2SchemaShadowPronounFixture(
            base: fixture,
            occurrenceAnchorAlternatives: occurrenceAnchors,
            globalAnchorGroups: globalAnchors
        )
    }
}
