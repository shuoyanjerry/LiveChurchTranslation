import Foundation
import Testing

@Suite("Hy-MT2 test-only negation shadow plan")
struct HyMT2NegationMarkerShadowPlanTests {
    @Test("assigns nonce-bound IDs to one, two, and three functional cues")
    func assignsStableOccurrenceMarkers() throws {
        for (index, fixture) in HyMT2NegationShadowFixtures.cardinalityCoverage.enumerated() {
            let plan = try fixture.plan(encoding: .originalCue)
            let expectedCount = index + 1
            let expectedIDs = (1...expectedCount).map { String(format: "N%04d", $0) }

            #expect(plan.occurrences.count == expectedCount)
            #expect(plan.occurrences.map(\.identifier) == expectedIDs)
            #expect(plan.occurrences.allSatisfy { $0.nonce == "C0DEC0DE2026" })
            #expect(plan.occurrences.allSatisfy { plan.protectedSource.contains($0.protectedBlock) })
        }
    }

    @Test("compares model-visible English placeholder and original-cue encodings")
    func comparesBothEncodings() throws {
        let fixture = HyMT2NegationShadowFixtures.singleNever
        let english = try fixture.plan(encoding: .englishNot)
        let original = try fixture.plan(encoding: .originalCue)
        let block = try #require(english.occurrences.first).protectedBlock

        #expect(english.protectedSource.contains(" not\(block) "))
        #expect(!english.protectedSource.contains("从未"))
        #expect(original.protectedSource.contains("从未\(block)"))
        #expect(english.occurrences == original.occurrences)
    }

    @Test("leaves nonfunctional constructions unmarked")
    func leavesNonFunctionalUsesUnmarked() throws {
        for fixture in HyMT2NegationShadowFixtures.nonFunctionalControls {
            for encoding in HyMT2NegationShadowEncoding.allCases {
                let plan = try fixture.plan(encoding: encoding)
                #expect(plan.occurrences.isEmpty, "Unexpected marker in \(fixture.name)")
                #expect(plan.protectedSource == fixture.source)
            }
        }
        let mixed = try HyMT2NegationShadowFixtures.mixedNonFunctional.plan(
            encoding: .originalCue
        )
        #expect(mixed.protectedSource.contains("不但传讲真理"))
        #expect(mixed.occurrences.count == 1)
    }

    @Test("embeds the shadow policy before the existing strict prompt")
    func buildsStrictPromptWithoutMarkingControls() throws {
        let plan = try HyMT2NegationShadowFixtures.three.plan(encoding: .englishNot)
        let prompt = HyMT2NegationMarkerShadowPrompt.make(plan)

        #expect(prompt.contains("TEST-ONLY NEGATION ALIGNMENT"))
        #expect(prompt.contains("保留所有数字、专名、明确否定和指定术语"))
        #expect(prompt.contains("not, no, never, cannot"))
        #expect(plan.occurrences.allSatisfy { prompt.contains($0.protectedBlock) })
        #expect(prompt.contains("<CURRENT_SOURCE>"))
    }

    @Test("rejects reserved, mismatched, and overlapping source annotations")
    func rejectsUnsafePlans() throws {
        let source = "教会不隐藏真理。"
        let range = try #require(source.range(of: "不"))
        let cue = HyMT2NegationShadowSourceCue(range: NSRange(range, in: source), text: "没有")
        #expect(throws: shadowFailure(.wrongSourceCue)) {
            try makePlan(source, cues: [cue])
        }
        let validCue = HyMT2NegationShadowSourceCue(range: cue.range, text: "不")
        let overlap = HyMT2NegationShadowSourceCue(
            range: NSRange(location: cue.range.location, length: 2),
            text: "不隐"
        )
        #expect(throws: shadowFailure(.overlappingSourceRange)) {
            try makePlan(source, cues: [overlap, validCue])
        }
        #expect(throws: shadowFailure(.reservedProtocolInput)) {
            try makePlan("QLR_NEG 不", cues: [])
        }
    }

    private func makePlan(
        _ source: String,
        cues: [HyMT2NegationShadowSourceCue]
    ) throws -> HyMT2NegationShadowPlan {
        try HyMT2NegationShadowPlan.make(
            source: source,
            functionalCues: cues,
            requestID: negationShadowRequestID,
            encoding: .originalCue
        )
    }

    private func shadowFailure(
        _ category: HyMT2NegationShadowFailureCategory
    ) -> HyMT2NegationShadowFailure {
        HyMT2NegationShadowFailure(category: category, identifier: nil)
    }
}
