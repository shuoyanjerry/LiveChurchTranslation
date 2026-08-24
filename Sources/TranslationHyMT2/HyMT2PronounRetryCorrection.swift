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

    struct Repair: Equatable, Sendable {
        let identifier: String
        let family: String

        var instruction: String {
            "REPAIR \(identifier): Immediately before \(identifier)'s existing exact marker, use "
                + "exactly one sentence-appropriate \(family) form."
        }
    }

    struct PossessiveRepair: Equatable, Sendable {
        let identifier: String
        let form: String

        var instruction: String {
            "POSSESSIVE \(identifier): Use \(form) immediately before \(identifier)'s existing "
                + "exact marker, then the noun."
        }
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
                "MISSING_ANCHOR: Copy every existing Q marker from CURRENT SOURCE unchanged "
                    + "exactly once and keep it bound to its corresponding pronoun."
            case .anchorShapeOrCardinality:
                "ANCHOR_SHAPE_OR_CARDINALITY: Preserve only the exact existing Q markers from "
                    + "CURRENT SOURCE, each exactly once; never alter, invent, or transfer one."
            case .pronounBindingOrPolicy:
                "PRONOUN_BINDING_OR_POLICY: Put each existing Q marker immediately after exactly "
                    + "one context-appropriate ASCII English pronoun."
            }
        }
    }

    private static let protocolRules = [
        "Output every existing Q marker unchanged exactly once and keep it with its corresponding pronoun.",
        "Put one permitted ASCII English pronoun immediately before each marker, with either zero "
            + "gap or one plain space.",
        "Never print a slash- or pipe-separated list of pronoun options.",
        "A marker may follow only one context-appropriate she, he, or singular-they form.",
    ]

    private static func code(for issue: OutputValidationIssue) -> Code? {
        switch issue {
        case .metaText, .promptControlDelimiter, .unexpectedSourceScript:
            .outputOnly
        case .missingPronounMarker:
            .missingAnchor
        case .duplicatePronounMarker, .unknownPronounMarker, .malformedPronounMarker,
            .pronounMarkerOrderMismatch, .pronounMarkerResolutionMismatch:
            .anchorShapeOrCardinality
        case .reusedPronounRealization, .wrongPronounRealization,
            .pronounAlternativeList:
            .pronounBindingOrPolicy
        default:
            nil
        }
    }

}
