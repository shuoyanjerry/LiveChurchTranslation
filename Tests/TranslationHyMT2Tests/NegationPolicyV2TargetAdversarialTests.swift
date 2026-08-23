import Testing

@Suite("Negation Policy V2 English target adversarial cases")
struct NegationPolicyV2TargetAdversarialTests {
    @Test("English cue counting uses occurrences and word boundaries")
    func countsOvertEnglishCues() {
        #expect(NegationPolicyV2English.overtCueCount(in: "This is notable.") == 0)
        #expect(NegationPolicyV2English.overtCueCount(in: "It is not final.") == 1)
        #expect(NegationPolicyV2English.overtCueCount(in: "It is NOT final.") == 1)
        #expect(NegationPolicyV2English.overtCueCount(in: "It isn't final.") == 1)
        #expect(NegationPolicyV2English.overtCueCount(in: "It isn’t final.") == 1)
        #expect(NegationPolicyV2English.overtCueCount(in: "It cannot fail without warning.") == 2)
    }

    @Test("English paired and non-functional constructions are not double-counted")
    func handlesEnglishConstructions() {
        #expect(
            NegationPolicyV2English.overtCueCount(
                in: "It is not only clear but compelling."
            ) == 0
        )
        #expect(
            NegationPolicyV2English.overtCueCount(
                in: "Neither fear nor shame remains."
            ) == 1
        )
        #expect(
            NegationPolicyV2English.overtCueCount(
                in: "Whether or not they come remains unknown."
            ) == 0
        )
        #expect(
            NegationPolicyV2English.overtCueCount(
                in: "No matter what happens, they will serve."
            ) == 0
        )
    }

    @Test("exact simple counts can pass only the structural negation dimension")
    func permitsNarrowStructuralPass() {
        #expect(
            NegationPolicyV2.disposition(
                source: "神没有忘记自己的应许。",
                target: "God has not forgotten his promise."
            ) == .requiresOvertCue(count: 1)
        )
        #expect(
            NegationPolicyV2.disposition(
                source: "教会不隐藏真理，也不忽略穷人。",
                target: "The church does not hide truth and does not ignore the poor."
            ) == .requiresOvertCue(count: 2)
        )
    }

    @Test("cue mismatch and lexical paraphrase remain review-only")
    func routesCountMismatchToReview() {
        #expect(
            NegationPolicyV2.disposition(
                source: "福音不可更改。",
                target: "The gospel is immutable."
            )
                == .humanReviewRequired(
                    reason: .targetCueCountMismatch(expected: 1, observed: 0)
                )
        )
        #expect(
            NegationPolicyV2.disposition(
                source: "神没有忘记自己的应许。",
                target: "God has not forgotten and will never abandon his promise."
            )
                == .humanReviewRequired(
                    reason: .targetCueCountMismatch(expected: 1, observed: 2)
                )
        )
    }

    @Test("format controls, compatibility letters, marks, and mixed scripts require review")
    func rejectsUnicodeCueLookalikes() {
        let targets = [
            "God does n\u{200B}ot leave.", "God does ｎｏｔ leave.",
            "God says no\u{0301}.", "God does nοt leave.",
        ]

        for target in targets {
            #expect(
                NegationPolicyV2.disposition(
                    source: "神不离开。",
                    target: target
                ) == .humanReviewRequired(reason: .unsafeTargetUnicode)
            )
        }
        #expect(
            NegationPolicyV2.sourceDisposition("神不\u{200B}离开。")
                == .humanReviewRequired(reason: .unsafeSourceUnicode)
        )
    }
}
