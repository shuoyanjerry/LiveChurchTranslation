enum HumanReviewResolutionBuilder {
    static func resolve(
        _ requirements: [TranslationHumanReviewRequirement],
        submissions: [TranslationHumanReviewSubmission]
    ) -> TranslationHumanReviewResolution {
        let verdicts = submissions.map {
            Dictionary(uniqueKeysWithValues: $0.reviews.map { ($0.itemID, $0.verdict) })
        }
        var resolved = 0
        var failed = 0
        for requirement in requirements {
            let values = verdicts.compactMap { $0[requirement.itemID] }
            if requirement.isHumanResolvable, values == [.pass, .pass] {
                resolved += 1
            } else {
                failed += 1
            }
        }
        return TranslationHumanReviewResolution(
            resolvedCount: resolved,
            outstandingCount: 0,
            reviewFailureCount: failed,
            bindingFailureCount: 0
        )
    }
}
