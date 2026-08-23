import Foundation

struct HyMT2NegationShadowQ4Fixture: Sendable {
    let identifier: String
    let base: HyMT2NegationShadowFixture
    let occurrenceAnchorAlternatives: [[String]]
    let globalAnchorGroups: [[String]]

    func plan(
        encoding: HyMT2NegationShadowEncoding,
        index: Int
    ) throws -> HyMT2NegationShadowPlan {
        try base.plan(encoding: encoding, requestID: requestID(index))
    }

    private func requestID(_ index: Int) throws -> UUID {
        let suffix = String(format: "%012X", index + 1)
        guard let value = UUID(uuidString: "C0DEC0DE-2026-4A22-B000-\(suffix)") else {
            throw HyMT2NegationShadowFixtureError.missingCue(identifier)
        }
        return value
    }
}

enum HyMT2NegationShadowQ4Fixtures {
    static let all = functional + mixed + controls

    private static let functional = [
        value(
            "one.not", HyMT2NegationShadowFixtures.singleNot, [["hide", "conceal"]],
            [
                ["church"], ["truth"],
            ]),
        value(
            "one.cannot",
            HyMT2NegationShadowFixtures.singleCannot,
            [["bear", "produce", "fruit"]],
            [["disciple"], ["fruit"]]
        ),
        value(
            "one.no", HyMT2NegationShadowFixtures.singleNo, [["justif"]],
            [
                ["work", "deed"], ["justif"],
            ]),
        value(
            "one.never", HyMT2NegationShadowFixtures.singleNever, [["forget", "forgot"]],
            [
                ["god", "lord"], ["promise"],
            ]),
        value(
            "two.no.never",
            HyMT2NegationShadowFixtures.two,
            [["justif"], ["forget", "forgot"]],
            [["work", "deed"], ["promise"]]
        ),
        value(
            "three.not.cannot.no",
            HyMT2NegationShadowFixtures.three,
            [["hide", "conceal"], ["save", "rescue"], ["forget", "forgot"]],
            [["church"], ["disciple"], ["god", "lord"], ["truth"], ["promise"]]
        ),
    ]

    private static let mixed = [
        value(
            "mixed.additive.not",
            HyMT2NegationShadowFixtures.mixedNonFunctional,
            [["hide", "conceal"]],
            [["church"], ["truth"], ["grace"]]
        )
    ]

    private static let controls = [
        value(
            "control.a.not.a", HyMT2NegationShadowFixtures.nonFunctionalControls[0], [],
            [
                ["believe", "faith"], ["promise"],
            ]),
        value(
            "control.continuous", HyMT2NegationShadowFixtures.nonFunctionalControls[1], [],
            [
                ["pray"], ["continual", "continuous", "constant", "keep"],
            ]),
        value(
            "control.different", HyMT2NegationShadowFixtures.nonFunctionalControls[2], [],
            [
                ["gift"], ["different", "distinct", "diverse", "various"],
            ]),
        value(
            "control.concessive", HyMT2NegationShadowFixtures.nonFunctionalControls[3], [],
            [
                ["pray"], ["regardless", "whatever", "despite", "matter"],
            ]),
    ]

    private static func value(
        _ identifier: String,
        _ base: HyMT2NegationShadowFixture,
        _ occurrenceAnchors: [[String]],
        _ globalAnchors: [[String]]
    ) -> HyMT2NegationShadowQ4Fixture {
        HyMT2NegationShadowQ4Fixture(
            identifier: identifier,
            base: base,
            occurrenceAnchorAlternatives: occurrenceAnchors,
            globalAnchorGroups: globalAnchors
        )
    }
}
