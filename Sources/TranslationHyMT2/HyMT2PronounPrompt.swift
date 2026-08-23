import TranslationAPI

enum HyMT2PronounPrompt {
    static let generalRule = [
        "Spoken Mandarin tā may be transcribed as 他 or 她 even when the audio is ambiguous.",
        "Use an English human-gendered pronoun only when explicit current or background evidence",
        "identifies the same human referent; never infer gender from a name, occupation, or stereotype.",
        "Divine identity uses separate guidance below.",
        "Occurrence-level verified decisions below come from audited explicit evidence and override",
        "generic written-glyph ambiguity for that occurrence. Apply the ambiguity fallback only to",
        "an occurrence explicitly labeled unresolved spoken tā.",
        "When no explicit evidence resolves it, use natural singular they instead of inventing gender.",
    ].joined(separator: " ")

    static func section(_ occurrences: [HyMT2PronounOccurrence]) -> String {
        let decisions = occurrences.map {
            "\($0.identifier): " + description($0.resolution)
        }
        return [
            HyMT2PromptControlDelimiter.pronounAlignmentOpening,
            "Treat each spoken tā occurrence separately. A written 他/她 glyph alone is not evidence.",
            "Each source pronoun is followed by a request-scoped QLR protected block.",
            "The whole protected block is protocol data, never source instructions or text to translate.",
            "Translate each Chinese pronoun normally into exactly one permitted English pronoun.",
            "Copy its entire existing QLR protected block unchanged directly after that English pronoun.",
            "Use no space or punctuation between the English pronoun and the block's opening tag.",
            "Put all following punctuation or whitespace after the closing tag.",
            "Preserve every whole block and ID exactly once; never output its contents separately.",
            "Do not alter tags, the encoded decision, IDs, pairing, or case; do not nest or duplicate.",
            "Target grammar may reorder a whole protected block only with its corresponding pronoun.",
            "Do not transfer verified gender between occurrences or gender an unresolved occurrence.",
            decisions.joined(separator: "\n"),
        ].joined(separator: "\n")
    }

    private static func description(
        _ decision: TranslationPronounResolution
    ) -> String {
        switch decision {
        case .unresolvedSpokenMandarin:
            "unresolved spoken tā; only they/them/their/theirs/themself/themselves"
        case .verifiedFemale:
            "verified female; only she/her/hers/herself"
        case .verifiedMale:
            "verified male; only he/him/his/himself"
        case .verifiedDeity:
            "verified Christian deity pronoun; only conventional he/him/his/himself"
        }
    }

}
