/// Provider-neutral text metrics for qualification reports.
public enum ASRQualificationTextMetrics {
    /// Strict English WER after case folding, apostrophe removal, and word tokenization.
    public static func normalizedEnglishWER(
        reference: String,
        hypothesis: String
    ) -> ASRWordErrorMeasurement {
        let referenceWords = normalizedEnglishWords(reference)
        let hypothesisWords = normalizedEnglishWords(hypothesis)
        return ASRWordErrorMeasurement(
            editCount: ASRWordAligner.editCount(
                reference: referenceWords,
                hypothesis: hypothesisWords
            ),
            referenceWordCount: referenceWords.count
        )
    }

    /// Strict Levenshtein CER after shared character normalization.
    public static func normalizedStrictCER(
        reference: String,
        hypothesis: String
    ) -> ASRCharacterErrorMeasurement {
        let referenceCharacters = normalizedCharacters(reference)
        let alignment = ASRCharacterAligner.strict(
            reference: referenceCharacters,
            hypothesis: normalizedCharacters(hypothesis)
        )
        return ASRCharacterErrorMeasurement(
            editCount: alignment.editCount,
            referenceCharacterCount: referenceCharacters.count
        )
    }

    /// Semiglobal CER that does not charge a hypothesis-only prefix or suffix.
    public static func normalizedEdgeFreeSemiglobalCER(
        reference: String,
        hypothesis: String
    ) -> ASRCharacterErrorMeasurement {
        let referenceCharacters = normalizedCharacters(reference)
        let edits = ASRCharacterAligner.edgeFreeSemiglobalEditCount(
            reference: referenceCharacters,
            hypothesis: normalizedCharacters(hypothesis)
        )
        return ASRCharacterErrorMeasurement(
            editCount: edits,
            referenceCharacterCount: referenceCharacters.count
        )
    }

    static func normalizedCharacters(_ text: String) -> [Character] {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    static func normalizedEnglishWords(_ text: String) -> [String] {
        let apostropheFree =
            text
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        let normalized = apostropheFree.lowercased().map { character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(normalized).split(whereSeparator: \Character.isWhitespace).map(String.init)
    }
}
