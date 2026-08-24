struct HumanReviewRawRequirement {
    let identity: HumanReviewRequirementIdentity
    let isHumanResolvable: Bool
}

struct HumanReviewRequirementIdentity {
    let segmentID: String
    let sourceID: String
    let sequence: Int
    let kind: HumanReviewRequirementKind
    let subject: String
}

enum HumanReviewRequirementCollector {
    static func collect(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) -> [HumanReviewRawRequirement] {
        semantic(attempt, segment: segment) + statuses(attempt) + backend(attempt)
    }

    private static func semantic(
        _ attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) -> [HumanReviewRawRequirement] {
        guard attempt.status == .success,
            segment.qualification.requiresHumanSemanticReview
        else { return [] }
        return HumanReviewAxis.allCases.map {
            requirement(attempt, kind: .semanticAxis, subject: $0.rawValue)
        }
    }

    private static func statuses(
        _ attempt: TranslationQualificationAttempt
    ) -> [HumanReviewRawRequirement] {
        let checks = attempt.preservationChecks.compactMap {
            $0.status == .humanReviewRequired
                ? requirement(attempt, kind: .preservationCheck, subject: $0.kind) : nil
        }
        let terms = attempt.glossaryTerms.compactMap {
            $0.status == .humanReviewRequired
                ? requirement(attempt, kind: .glossaryTerm, subject: $0.source) : nil
        }
        let pronouns = attempt.pronounResults.flatMap {
            pronounRequirements(attempt, result: $0)
        }
        return checks + terms + pronouns
    }

    private static func pronounRequirements(
        _ attempt: TranslationQualificationAttempt,
        result: TranslationQualificationPronounResult
    ) -> [HumanReviewRawRequirement] {
        var requirements: [HumanReviewRawRequirement] = []
        if result.guidanceStatus == .humanReviewRequired {
            requirements.append(
                requirement(attempt, kind: .pronounGuidance, subject: result.occurrenceID)
            )
        }
        if result.englishPolicyStatus == .humanReviewRequired {
            requirements.append(
                requirement(attempt, kind: .pronounEnglishPolicy, subject: result.occurrenceID)
            )
        }
        return requirements
    }

    private static func backend(
        _ attempt: TranslationQualificationAttempt
    ) -> [HumanReviewRawRequirement] {
        (attempt.backendReviewIssueCodes ?? []).map { code in
            requirement(
                attempt,
                kind: .backendQualityWarning,
                subject: code,
                isHumanResolvable: resolvableBackendCodes.contains(code)
            )
        }
    }

    private static func requirement(
        _ attempt: TranslationQualificationAttempt,
        kind: HumanReviewRequirementKind,
        subject: String,
        isHumanResolvable: Bool = true
    ) -> HumanReviewRawRequirement {
        HumanReviewRawRequirement(
            identity: HumanReviewRequirementIdentity(
                segmentID: attempt.segmentID,
                sourceID: attempt.sourceID,
                sequence: attempt.sequence,
                kind: kind,
                subject: subject
            ),
            isHumanResolvable: isHumanResolvable
        )
    }

    private static let resolvableBackendCodes = Set([
        "quality.implausible_length", "quality.missing_required_term",
        "quality.missing_number", "quality.missing_negation",
        "quality.scripture_reference", "quality.pronoun_alignment",
    ])
}
