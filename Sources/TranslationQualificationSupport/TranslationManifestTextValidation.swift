extension TranslationManifestValidator {
    static func validateTextAndOccurrences(
        _ segment: TranslationQualificationSegment
    ) throws {
        let original = Array(segment.originalChinese.unicodeScalars)
        let observed = Array(segment.observedASRAmbiguousChinese.unicodeScalars)
        try require(original.count == observed.count, "ta degradation changed scalar count")
        for index in original.indices {
            let originalGlyph = String(original[index])
            let expected = ["她", "祂"].contains(originalGlyph) ? "他" : originalGlyph
            try require(String(observed[index]) == expected, "ta degradation changed non-ta content")
        }
        let expectedOffsets = original.indices.filter {
            ["他", "她", "祂"].contains(String(original[$0]))
        }
        let actualOffsets = segment.pronounOccurrences.map(\.unicodeScalarOffset)
        try require(expectedOffsets == actualOffsets, "occurrence offsets do not cover all ta glyphs")
        try validateOccurrences(segment.pronounOccurrences, original: original, observed: observed)
    }

    private static func validateOccurrences(
        _ occurrences: [TranslationPronounOccurrence],
        original: [Unicode.Scalar],
        observed: [Unicode.Scalar]
    ) throws {
        var occurrenceIDs = Set<String>()
        for occurrence in occurrences {
            try require(occurrenceIDs.insert(occurrence.id).inserted, "duplicate occurrence ID")
            let offset = occurrence.unicodeScalarOffset
            try require(original.indices.contains(offset), "occurrence offset out of range")
            try require(String(original[offset]) == occurrence.originalGlyph, "original glyph mismatch")
            try require(String(observed[offset]) == occurrence.observedGlyph, "observed glyph mismatch")
            try require(occurrence.observedGlyph == "他", "observed ta must be 他")
        }
    }
}
