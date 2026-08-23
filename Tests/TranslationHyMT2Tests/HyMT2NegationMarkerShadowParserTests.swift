import Foundation
import Testing

@Suite("Hy-MT2 test-only negation shadow parser")
struct HyMT2NegationMarkerShadowParserTests {
    @Test("accepts not, cannot, no, and never as overt bindings")
    func acceptsRequiredNegatorCoverage() throws {
        let negators = ["not", "cannot", "no", "never"]
        for (fixture, negator) in zip(HyMT2NegationShadowFixtures.lexicalCoverage, negators) {
            let plan = try fixture.plan(encoding: .originalCue)
            let marker = try block(plan, 0)
            let marked = negator + marker
            let output = "A faithful clause uses \(marked)."
            let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)

            #expect(parsed.cleanTarget == "A faithful clause uses \(negator).")
            #expect(parsed.bindings == [.init(identifier: "N0001", englishNegator: negator)])
            #expect(!parsed.cleanTarget.contains("QLR_NEG"))
        }
    }

    @Test("requires independent bindings for two occurrences")
    func acceptsTwoIndependentOccurrences() throws {
        let plan = try HyMT2NegationShadowFixtures.two.plan(encoding: .englishNot)
        let output =
            "No\(try block(plan, 0)) one is justified by works, and God "
            + "never\(try block(plan, 1)) forgets the promise."
        let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)

        #expect(parsed.cleanTarget == "No one is justified by works, and God never forgets the promise.")
        #expect(parsed.bindings.map(\.englishNegator) == ["no", "never"])
    }

    @Test("requires independent bindings for three occurrences")
    func acceptsThreeIndependentOccurrences() throws {
        let plan = try HyMT2NegationShadowFixtures.three.plan(encoding: .originalCue)
        let output =
            "The church does not\(try block(plan, 0)) hide truth; disciples "
            + "cannot\(try block(plan, 1)) save themselves; no\(try block(plan, 2)) promise is lost."
        let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)

        #expect(parsed.bindings.map(\.identifier) == ["N0001", "N0002", "N0003"])
        #expect(parsed.bindings.map(\.englishNegator) == ["not", "cannot", "no"])
        #expect(!parsed.cleanTarget.contains("N000"))
    }

    @Test("accepts only an adjacent standard contraction")
    func handlesContractionsStrictly() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNot.plan(encoding: .originalCue)
        let valid = "The church doesn't\(try block(plan, 0)) hide truth."
        let parsed = try HyMT2NegationMarkerShadowParser.parse(valid, plan: plan)
        #expect(parsed.bindings.first?.englishNegator == "doesn't")

        let invented = "The church blargn't\(try block(plan, 0)) hide truth."
        #expect(throws: shadowFailure(.unboundNegator, "N0001")) {
            try HyMT2NegationMarkerShadowParser.parse(invented, plan: plan)
        }
    }

    @Test("classifies missing and duplicated blocks without source text")
    func classifiesCardinalityFailures() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNot.plan(encoding: .originalCue)
        #expect(throws: shadowFailure(.missingBlock, "N0001")) {
            try HyMT2NegationMarkerShadowParser.parse("The church does not hide truth.", plan: plan)
        }
        let marked = "not\(try block(plan, 0))"
        #expect(throws: shadowFailure(.duplicateBlock, "N0001")) {
            try HyMT2NegationMarkerShadowParser.parse("It does \(marked), but does \(marked).", plan: plan)
        }
    }

    @Test("rejects wrong nonce, malformed blocks, and protocol residue")
    func classifiesProtocolFailures() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNever.plan(encoding: .originalCue)
        let validBlock = try block(plan, 0)
        let wrongNonce = validBlock.replacingOccurrences(
            of: "C0DEC0DE2026",
            with: "AAAAAAAAAAAA"
        )
        #expect(throws: shadowFailure(.unexpectedBlock, nil)) {
            try HyMT2NegationMarkerShadowParser.parse("God never\(wrongNonce) forgets.", plan: plan)
        }
        #expect(throws: shadowFailure(.unexpectedBlock, nil)) {
            let malformed = validBlock.replacingOccurrences(of: "QLR_NEG_LOCK", with: "LOCK")
            return try HyMT2NegationMarkerShadowParser.parse(
                "God never\(malformed) forgets.",
                plan: plan
            )
        }
        #expect(throws: shadowFailure(.residualProtocol, nil)) {
            try HyMT2NegationMarkerShadowParser.parse(
                "God never\(validBlock) forgets. N0001",
                plan: plan
            )
        }
    }

    @Test("rejects spacing, punctuation, and non-negator lexical binding")
    func classifiesBindingFailures() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNot.plan(encoding: .originalCue)
        let marker = try block(plan, 0)
        let invalid = [
            "not \(marker)", "not,\(marker)", "noteworthy\(marker)", "not\(marker)eworthy",
        ]
        for output in invalid {
            #expect(throws: shadowFailure(.unboundNegator, "N0001")) {
                try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)
            }
        }
    }

    @Test("rejects normalized fragments left outside otherwise valid blocks")
    func rejectsObfuscatedProtocolResidue() throws {
        let plan = try HyMT2NegationShadowFixtures.singleNot.plan(encoding: .originalCue)
        let marker = try block(plan, 0)
        #expect(throws: shadowFailure(.unexpectedBlock, nil)) {
            try HyMT2NegationMarkerShadowParser.parse(
                "The church does not\(marker) hide truth. Q L R / N 0 0 0 1",
                plan: plan
            )
        }
    }

    private func block(
        _ plan: HyMT2NegationShadowPlan,
        _ index: Int
    ) throws -> String {
        try #require(plan.occurrences.indices.contains(index))
        return plan.occurrences[index].protectedBlock
    }

    private func shadowFailure(
        _ category: HyMT2NegationShadowFailureCategory,
        _ identifier: String?
    ) -> HyMT2NegationShadowFailure {
        HyMT2NegationShadowFailure(category: category, identifier: identifier)
    }
}
