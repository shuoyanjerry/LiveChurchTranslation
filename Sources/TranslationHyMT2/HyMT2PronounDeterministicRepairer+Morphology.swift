import TranslationAPI

extension HyMT2PronounDeterministicRepairer {
    static func replacement(
        for binding: HyMT2PronounRepairBinding,
        occurrence: HyMT2PronounOccurrence
    ) -> String? {
        let source = binding.word
        guard let observed = PronounForm(rawValue: source.lowercased()),
            let slot = slot(for: observed, hint: occurrence.morphologyHint),
            isAgreementSafe(observed: observed, slot: slot, expected: occurrence.resolution)
        else { return nil }
        let replacement = form(for: occurrence.resolution, slot: slot, observed: observed)
        return applyingCase(of: source, to: replacement)
    }

    private static func slot(
        for form: PronounForm,
        hint: HyMT2PronounMorphologyHint
    ) -> MorphologySlot? {
        switch hint {
        case .possessiveDeterminer: .possessiveDeterminer
        case .possessiveIndependent: .possessiveIndependent
        case .unspecified: form.nonPossessiveSlot
        }
    }

    private static func isAgreementSafe(
        observed: PronounForm,
        slot: MorphologySlot,
        expected: TranslationPronounResolution
    ) -> Bool {
        guard slot == .subject else { return true }
        let observedIsNeutral = observed.family == .neutral
        let expectedIsNeutral = expected == .unresolvedSpokenMandarin
        return observedIsNeutral == expectedIsNeutral
    }

    private static func form(
        for resolution: TranslationPronounResolution,
        slot: MorphologySlot,
        observed: PronounForm
    ) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin: neutralForm(slot: slot, observed: observed)
        case .verifiedFemale: feminineForm(slot: slot)
        case .verifiedMale, .verifiedDeity: masculineForm(slot: slot)
        }
    }

    private static func neutralForm(slot: MorphologySlot, observed: PronounForm) -> String {
        switch slot {
        case .subject: "they"
        case .object: "them"
        case .possessiveDeterminer: "their"
        case .possessiveIndependent: "theirs"
        case .reflexive: observed == .themselves ? "themselves" : "themself"
        }
    }

    private static func feminineForm(slot: MorphologySlot) -> String {
        switch slot {
        case .subject: "she"
        case .object, .possessiveDeterminer: "her"
        case .possessiveIndependent: "hers"
        case .reflexive: "herself"
        }
    }

    private static func masculineForm(slot: MorphologySlot) -> String {
        switch slot {
        case .subject: "he"
        case .object: "him"
        case .possessiveDeterminer, .possessiveIndependent: "his"
        case .reflexive: "himself"
        }
    }

    private static func applyingCase(of source: String, to replacement: String) -> String {
        if source == source.uppercased() { return replacement.uppercased() }
        guard source.first?.isUppercase == true else { return replacement }
        return replacement.prefix(1).uppercased() + String(replacement.dropFirst())
    }
}
