struct UnresolvedPronounNotice: Equatable, Sendable {
    static let accessibilityHint =
        "The translation preserves uncertainty instead of guessing gender."

    let text: String
    let accessibilityLabel: String

    init?(unresolvedCount: Int) {
        guard unresolvedCount > 0 else { return nil }

        if unresolvedCount == 1 {
            text = "Pronoun context unresolved · neutral English"
            accessibilityLabel =
                "One spoken Mandarin pronoun remains unresolved. Neutral English was used."
        } else {
            text = "\(unresolvedCount) pronoun contexts unresolved · neutral English"
            accessibilityLabel =
                "\(unresolvedCount) spoken Mandarin pronouns remain unresolved. Neutral English was used."
        }
    }
}
