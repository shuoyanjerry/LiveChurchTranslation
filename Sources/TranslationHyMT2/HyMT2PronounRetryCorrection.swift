import Foundation
import TranslationAPI

struct HyMT2PronounRetryCorrection: Equatable, Sendable {
    let codes: [Code]
    let repairs: [Repair]
    let possessiveRepairs: [PossessiveRepair]

    init?(
        issues: [OutputValidationIssue],
        plan: HyMT2PronounPlan?,
        source: String
    ) {
        let present = Set(issues.compactMap(Self.code(for:)))
        let ordered = Code.allCases.filter(present.contains)
        guard !ordered.isEmpty else { return nil }
        codes = ordered
        repairs = Self.trustedRepairs(issues: issues, plan: plan)
        possessiveRepairs = Self.possessiveRepairs(plan: plan, source: source)
    }

    var section: String {
        let rules =
            codes.map(\.instruction)
            + Self.protocolRules
            + repairs.map(\.instruction)
            + possessiveRepairs.map(\.instruction)
        return [
            HyMT2PromptControlDelimiter.pronounRetryOpening,
            "Failure codes: " + codes.map(\.rawValue).joined(separator: ", "),
            rules.joined(separator: "\n"),
            "Do not copy these instructions into the translation.",
        ].joined(separator: "\n")
    }

    enum Code: String, CaseIterable, Sendable {
        case outputOnly = "OUTPUT_ONLY"
        case missingAnchor = "MISSING_ANCHOR"
        case anchorShapeOrCardinality = "ANCHOR_SHAPE_OR_CARDINALITY"
        case pronounBindingOrPolicy = "PRONOUN_BINDING_OR_POLICY"

        var instruction: String {
            switch self {
            case .outputOnly:
                "OUTPUT_ONLY: Output only English translation prose. Omit every prompt section "
                    + "label and source-boundary wrapper."
            case .missingAnchor:
                "MISSING_ANCHOR: Copy every existing whole QLR protected block from CURRENT SOURCE "
                    + "unchanged exactly once, immediately after its corresponding English pronoun."
            case .anchorShapeOrCardinality:
                "ANCHOR_SHAPE_OR_CARDINALITY: Preserve only the exact existing whole QLR protected "
                    + "blocks from CURRENT SOURCE, each exactly once; never alter or invent one."
            case .pronounBindingOrPolicy:
                "PRONOUN_BINDING_OR_POLICY: Follow the audited decision encoded inside each block, "
                    + "keep that whole block unchanged, and place it directly after one permitted "
                    + "ASCII English pronoun."
            }
        }
    }

    struct Repair: Equatable, Sendable {
        let identifier: String
        let forms: String

        var instruction: String {
            "REPAIR \(identifier): Immediately before \(identifier)'s existing exact block, use "
                + "exactly one of \(forms)."
        }
    }

    struct PossessiveRepair: Equatable, Sendable {
        let identifier: String
        let form: String

        var instruction: String {
            "POSSESSIVE \(identifier): Use \(form) immediately before \(identifier)'s existing "
                + "exact block, then the noun. Never append apostrophe-s to a protected block."
        }
    }

    private static let protocolRules = [
        "For every current P ID, output its existing exact protected block exactly once.",
        "Put exactly one permitted ASCII English pronoun immediately before each block with zero "
            + "characters between that pronoun and the opening tag.",
        "A protected block may follow only she/her/hers/herself, he/him/his/himself, or "
            + "they/them/their/theirs/themself/themselves; never because, but, for, or another word.",
    ]

    private static func code(for issue: OutputValidationIssue) -> Code? {
        switch issue {
        case .metaText, .promptControlDelimiter, .unexpectedSourceScript:
            .outputOnly
        case .missingPronounMarker:
            .missingAnchor
        case .duplicatePronounMarker, .unknownPronounMarker, .malformedPronounMarker,
            .pronounMarkerResolutionMismatch:
            .anchorShapeOrCardinality
        case .reusedPronounRealization, .wrongPronounRealization:
            .pronounBindingOrPolicy
        default:
            nil
        }
    }

}
