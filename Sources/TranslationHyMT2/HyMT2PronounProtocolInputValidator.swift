import TranslationAPI

enum HyMT2PronounProtocolInputValidator {
    static func validate(
        source: String,
        context: [TranslationContextEntry],
        terms: [TranslationTerm]
    ) throws {
        try rejectReservedPrefix(in: [source], field: "current source")
        try rejectReservedPrefix(
            in: context.flatMap { [$0.sourceText, $0.targetText] },
            field: "translation context"
        )
        try rejectReservedPrefix(
            in: terms.flatMap {
                [$0.source, $0.target] + $0.sourceAliases + $0.acceptedTargets
            },
            field: "glossary"
        )
    }

    private static func rejectReservedPrefix(
        in values: [String],
        field: String
    ) throws {
        let containsCollision = values.contains { value in
            HyMT2ReservedProtocolText.containsPrefix(in: value)
        }
        guard !containsCollision else {
            throw OutputValidationFailure(
                issues: [.reservedPronounMarkerCollision(field)]
            )
        }
    }
}
