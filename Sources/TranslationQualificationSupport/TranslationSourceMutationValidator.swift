enum TranslationSourceMutationValidator {
    static func validate(
        attempt: TranslationQualificationAttempt,
        segment: TranslationQualificationSegment
    ) throws {
        let observed = Array(segment.observedASRAmbiguousChinese.unicodeScalars)
        let translated = Array(attempt.translationSourceText.unicodeScalars)
        try require(observed.count == translated.count, "translation source changed scalar count")
        let results = Dictionary(
            uniqueKeysWithValues: attempt.pronounResults.map { ($0.occurrenceID, $0) }
        )
        let occurrences = Dictionary(
            uniqueKeysWithValues: segment.pronounOccurrences.map { ($0.unicodeScalarOffset, $0) }
        )
        for index in observed.indices where observed[index] != translated[index] {
            guard
                let occurrence = occurrences[index],
                occurrence.tokenClass == .singularPronoun,
                let result = results[occurrence.id],
                permittedReplacement(for: result.actualGuidance) == String(translated[index])
            else {
                throw TranslationQualificationError.invalidReport(
                    "translation source contains an unapproved mutation"
                )
            }
        }
    }

    private static func permittedReplacement(for guidance: String) -> String? {
        switch guidance {
        case "verifiedFemale": "她"
        case "verifiedMale": "他"
        case "verifiedDeity": "祂"
        default: nil
        }
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }
}
