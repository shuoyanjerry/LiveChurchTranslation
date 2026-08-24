struct TranslationHumanReviewRequirement: Sendable {
    let itemID: String
    let isHumanResolvable: Bool
    let identity: HumanReviewRequirementIdentity
}

enum TranslationHumanReviewRequirements {
    static func derive(
        attempts: [TranslationQualificationAttempt],
        segments: [TranslationQualificationSegment],
        reportBinding: TranslationHumanReviewReportBinding
    ) throws -> [TranslationHumanReviewRequirement] {
        guard attempts.count == segments.count else {
            throw TranslationQualificationError.invalidReport(
                "human review attempt coverage is inconsistent"
            )
        }
        var raw: [HumanReviewRawRequirement] = []
        for (attempt, segment) in zip(attempts, segments) {
            try requireSameIdentity(attempt, segment)
            raw += HumanReviewRequirementCollector.collect(attempt, segment: segment)
        }
        let requirements = raw.map {
            TranslationHumanReviewRequirement(
                itemID: HumanReviewItemIdentifier.make($0.identity, binding: reportBinding),
                isHumanResolvable: $0.isHumanResolvable,
                identity: $0.identity
            )
        }.sorted { $0.itemID < $1.itemID }
        guard Set(requirements.map(\.itemID)).count == requirements.count else {
            throw TranslationQualificationError.invalidReport(
                "human review requirement identity is duplicated"
            )
        }
        return requirements
    }

    private static func requireSameIdentity(
        _ attempt: TranslationQualificationAttempt,
        _ segment: TranslationQualificationSegment
    ) throws {
        guard attempt.segmentID == segment.id,
            attempt.sourceID == segment.sourceID,
            attempt.sequence == segment.sequence
        else {
            throw TranslationQualificationError.invalidReport(
                "human review attempt identity is inconsistent"
            )
        }
    }
}
