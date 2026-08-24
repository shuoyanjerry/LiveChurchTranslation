import Foundation

public struct TranslationQualificationTermExpectation: Equatable, Sendable {
    public let source: String
    public let preferredTarget: String
    public let acceptedTargets: [String]
    public let required: Bool

    public init(
        source: String,
        preferredTarget: String,
        acceptedTargets: [String] = [],
        required: Bool
    ) {
        self.source = source
        self.preferredTarget = preferredTarget
        self.acceptedTargets = acceptedTargets
        self.required = required
    }
}

public struct TranslationQualificationPreservation: Equatable, Sendable {
    public let terms: [TranslationQualificationTermResult]
    public let checks: [TranslationQualificationCheck]

    public init(
        terms: [TranslationQualificationTermResult],
        checks: [TranslationQualificationCheck]
    ) {
        self.terms = terms
        self.checks = checks
    }
}

public enum TranslationPreservationEvaluator {
    public static func evaluate(
        segment: TranslationQualificationSegment,
        hypothesis: String?,
        terms: [TranslationQualificationTermExpectation]
    ) -> TranslationQualificationPreservation {
        TranslationQualificationPreservation(
            terms: termResults(terms, hypothesis: hypothesis),
            checks: [
                negationCheck(source: segment.observedASRAmbiguousChinese, hypothesis: hypothesis),
                numberCheck(
                    source: segment.observedASRAmbiguousChinese,
                    tagged: segment.featureTags.contains("number"),
                    hypothesis: hypothesis
                ),
                scriptureCheck(
                    source: segment.observedASRAmbiguousChinese,
                    tagged: segment.featureTags.contains("scripture"),
                    hypothesis: hypothesis
                ),
                reviewCheck(
                    kind: "properNames",
                    applicable: segment.qualification.semanticScoringEligible,
                    hypothesis: hypothesis
                ),
                reviewCheck(
                    kind: "humanReferenceSemantics",
                    applicable: segment.qualification.semanticScoringEligible,
                    hypothesis: hypothesis
                ),
            ]
        )
    }

    private static func termResults(
        _ terms: [TranslationQualificationTermExpectation],
        hypothesis: String?
    ) -> [TranslationQualificationTermResult] {
        terms.map { term in
            let accepted = [term.preferredTarget] + term.acceptedTargets
            let preserved =
                hypothesis.map { target in
                    accepted.contains {
                        TranslationTargetTermMatcher.contains($0, in: target)
                    }
                } ?? false
            return TranslationQualificationTermResult(
                source: term.source,
                preferredTarget: term.preferredTarget,
                acceptedTargets: term.acceptedTargets,
                required: term.required,
                status: preserved ? .pass : (term.required ? .fail : .humanReviewRequired)
            )
        }
    }

    private static func numberCheck(
        source: String,
        tagged: Bool,
        hypothesis: String?
    ) -> TranslationQualificationCheck {
        let sourceNumbers = matches(#"\d+"#, in: source)
        guard tagged || !sourceNumbers.isEmpty else { return check("numbers", .notApplicable) }
        guard let hypothesis else { return check("numbers", .fail, expected: sourceNumbers) }
        guard !sourceNumbers.isEmpty else {
            return check("numbers", .humanReviewRequired)
        }
        var observed = matches(#"\d+"#, in: hypothesis)
        let missing = sourceNumbers.filter { value in
            guard let index = observed.firstIndex(of: value) else { return true }
            observed.remove(at: index)
            return false
        }
        return check(
            "numbers",
            missing.isEmpty ? .pass : .fail,
            expected: sourceNumbers,
            observed: matches(#"\d+"#, in: hypothesis)
        )
    }

    private static func scriptureCheck(
        source: String,
        tagged: Bool,
        hypothesis: String?
    ) -> TranslationQualificationCheck {
        let references = matches(
            #"[0-9零〇一二两三四五六七八九十百千]+章[0-9零〇一二两三四五六七八九十百千]+节"#,
            in: source
        )
        guard tagged || !references.isEmpty else { return check("scriptureReference", .notApplicable) }
        guard let hypothesis else {
            return check("scriptureReference", .fail, expected: references)
        }
        guard !references.isEmpty else {
            return check("scriptureReference", .humanReviewRequired)
        }
        let observed = matches(#"\d+\s*:\s*\d+"#, in: hypothesis)
        let words = Set(englishWords(hypothesis))
        let preserved = !observed.isEmpty || (words.contains("chapter") && words.contains("verse"))
        return check(
            "scriptureReference",
            preserved ? .pass : .fail,
            expected: references,
            observed: observed
        )
    }

}
