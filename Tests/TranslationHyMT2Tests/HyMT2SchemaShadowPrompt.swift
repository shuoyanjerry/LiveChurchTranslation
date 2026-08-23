import TranslationAPI
@testable import TranslationHyMT2

enum HyMT2SchemaShadowPrompt {
    static func make(
        annotatedSource: String,
        family: HyMT2SchemaShadowFamily,
        occurrences: [HyMT2SchemaShadowOccurrence]
    ) -> String {
        let base = HyMT2PromptBuilder.prompt(
            source: annotatedSource,
            targetLanguage: "en",
            terms: [],
            strict: true
        )
        let decisions = occurrences.map(decision).joined(separator: "\n")
        let rules = [
            "TEST-ONLY STRUCTURED RESPONSE PROTOCOL:",
            "Return only the JSON object required by the response schema, not plain text.",
            "The source annotations identify independent occurrences; never translate annotations.",
            "In target_template, represent every listed occurrence by its exact {{ID}} placeholder",
            "once and only once at that occurrence's grammatical target position.",
            "A whole placeholder may move with its meaning when English word order requires it.",
            "Never swap meanings, invent IDs, emit QLR text, or leave source annotations in output.",
            "For each required bindings.ID.surface, choose one schema-permitted English surface.",
            "The application will deterministically replace each placeholder with that surface.",
            familyRule(family),
            decisions,
        ].joined(separator: "\n")
        return rules + "\n\n" + base
    }

    private static func decision(_ occurrence: HyMT2SchemaShadowOccurrence) -> String {
        let choices = occurrence.allowedSurfaces.joined(separator: ", ")
        if let resolution = occurrence.resolution {
            return "\(occurrence.identifier) => \(occurrence.placeholder): "
                + "\(description(resolution)); allowed: \(choices)"
        }
        return "\(occurrence.identifier) => \(occurrence.placeholder): "
            + "functional negation; allowed: \(choices)"
    }

    private static func familyRule(_ family: HyMT2SchemaShadowFamily) -> String {
        switch family {
        case .negation:
            "Each placeholder replaces exactly one overt English negator for its source scope."
        case .pronoun:
            "Each placeholder replaces exactly one English pronoun for its source referent and role."
        }
    }

    private static func description(_ resolution: TranslationPronounResolution) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin: "unresolved spoken tā; use natural singular they"
        case .verifiedFemale: "verified female"
        case .verifiedMale: "verified male"
        case .verifiedDeity: "verified Christian deity"
        }
    }
}
