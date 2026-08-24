import TranslationAPI

extension HyMT2PronounRetryCorrection {
    static func trustedRepairs(
        issues: [OutputValidationIssue],
        plan: HyMT2PronounPlan?
    ) -> [Repair] {
        guard let plan else { return [] }
        let identifiers = Set(
            issues.compactMap { trustedOccurrence(for: $0, in: plan)?.identifier }
        )
        return plan.occurrences.compactMap { occurrence in
            guard identifiers.contains(occurrence.identifier) else { return nil }
            return Repair(
                identifier: occurrence.identifier,
                family: familyName(for: occurrence.resolution)
            )
        }
    }

    static func possessiveRepairs(
        plan: HyMT2PronounPlan?,
        source _: String
    ) -> [PossessiveRepair] {
        guard let plan else { return [] }
        return plan.occurrences.compactMap { occurrence in
            guard let form = possessiveForm(for: occurrence) else { return nil }
            return PossessiveRepair(identifier: occurrence.identifier, form: form)
        }
    }

    private static func trustedOccurrence(
        for issue: OutputValidationIssue,
        in plan: HyMT2PronounPlan
    ) -> HyMT2PronounOccurrence? {
        switch issue {
        case .missingPronounMarker(let identifier, let range, let resolution),
            .wrongPronounRealization(let identifier, let range, let resolution, _):
            plan.occurrences.first {
                $0.identifier == identifier
                    && $0.sourceRange == range
                    && $0.resolution == resolution
            }
        default:
            nil
        }
    }

    private static func familyName(
        for resolution: TranslationPronounResolution
    ) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin: "singular-they-family"
        case .verifiedFemale: "she-family"
        case .verifiedMale, .verifiedDeity: "he-family"
        }
    }

    private static func possessiveForm(
        for occurrence: HyMT2PronounOccurrence
    ) -> String? {
        switch (occurrence.resolution, occurrence.morphologyHint) {
        case (.unresolvedSpokenMandarin, .possessiveDeterminer): "their"
        case (.unresolvedSpokenMandarin, .possessiveIndependent): "theirs"
        case (.verifiedFemale, .possessiveDeterminer): "her"
        case (.verifiedFemale, .possessiveIndependent): "hers"
        case (.verifiedMale, .possessiveDeterminer),
            (.verifiedMale, .possessiveIndependent),
            (.verifiedDeity, .possessiveDeterminer),
            (.verifiedDeity, .possessiveIndependent):
            "his"
        case (_, .unspecified):
            nil
        }
    }
}
