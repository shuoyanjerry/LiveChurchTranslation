import Foundation
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
                forms: allowedForms(for: occurrence.resolution)
            )
        }
    }

    static func trustedOccurrence(
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

    static func possessiveRepairs(
        plan: HyMT2PronounPlan?,
        source: String
    ) -> [PossessiveRepair] {
        guard let plan else { return [] }
        return plan.occurrences.compactMap { occurrence in
            guard isPossessive(occurrence.sourceRange, in: source) else { return nil }
            return PossessiveRepair(
                identifier: occurrence.identifier,
                form: possessiveForm(for: occurrence.resolution)
            )
        }
    }

    private static func isPossessive(
        _ sourceRange: TranslationSourceRange,
        in source: String
    ) -> Bool {
        guard
            let range = Range(
                NSRange(location: sourceRange.location, length: sourceRange.length),
                in: source
            ),
            range.upperBound < source.endIndex,
            source[range.upperBound] == "的"
        else { return false }
        let noun = source.index(after: range.upperBound)
        guard noun < source.endIndex else { return false }
        return !source[noun].isWhitespace && !source[noun].isPunctuation
    }

    private static func allowedForms(
        for resolution: TranslationPronounResolution
    ) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin:
            "they/them/their/theirs/themself/themselves"
        case .verifiedFemale:
            "she/her/hers/herself"
        case .verifiedMale, .verifiedDeity:
            "he/him/his/himself"
        }
    }

    private static func possessiveForm(
        for resolution: TranslationPronounResolution
    ) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin: "their"
        case .verifiedFemale: "her"
        case .verifiedMale, .verifiedDeity: "his"
        }
    }
}
