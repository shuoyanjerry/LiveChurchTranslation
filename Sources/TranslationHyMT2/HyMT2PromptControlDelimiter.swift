import Foundation

enum HyMT2PromptControlDelimiter {
    static let currentSourceOpening = "<CURRENT_SOURCE>"
    static let currentSourceClosing = "</CURRENT_SOURCE>"
    static let backgroundOpening = "BACKGROUND FOR DISAMBIGUATION ONLY"
    static let backgroundClosing = "END BACKGROUND"
    static let glossaryOpening = "Reference the following translations:"
    static let pronounAlignmentOpening = "MANDATORY PRONOUN ALIGNMENT FOR CURRENT SOURCE"
    static let pronounRetryOpening = "PRONOUN PROTOCOL CORRECTION FOR STRICT RETRY"

    static let sectionHeaders = [
        backgroundOpening,
        backgroundClosing,
        glossaryOpening,
        pronounAlignmentOpening,
        pronounRetryOpening,
    ]

    static let all = [currentSourceOpening, currentSourceClosing] + sectionHeaders

    static func occurs(in value: String) -> Bool {
        let inspected = inspectionKey(value)
        return all.contains { delimiter in
            inspected.contains(inspectionKey(delimiter))
        }
    }

    private static func inspectionKey(_ value: String) -> String {
        inspectionForm(value)
            .lowercased()
            .filter { !$0.isWhitespace }
    }

    private static func inspectionForm(_ value: String) -> String {
        var inspected = value
        for _ in 0..<3 {
            let normalized = removingFormatCharacters(
                from: inspected.precomposedStringWithCompatibilityMapping
            )
            let decoded = decodingAngleBracketEntities(in: normalized)
            if decoded == inspected { return decoded }
            inspected = decoded
        }
        return removingFormatCharacters(
            from: inspected.precomposedStringWithCompatibilityMapping
        )
    }

    private static func decodingAngleBracketEntities(in value: String) -> String {
        var decoded = value
        for _ in 0..<2 {
            decoded =
                decoded
                .replacingOccurrences(
                    of: #"&(?:lt|#0*60|#x0*3c);"#,
                    with: "<",
                    options: [.regularExpression, .caseInsensitive]
                )
                .replacingOccurrences(
                    of: #"&(?:gt|#0*62|#x0*3e);"#,
                    with: ">",
                    options: [.regularExpression, .caseInsensitive]
                )
                .replacingOccurrences(
                    of: "&amp;",
                    with: "&",
                    options: .caseInsensitive
                )
        }
        return decoded
    }

    private static func removingFormatCharacters(from value: String) -> String {
        value.replacingOccurrences(
            of: #"\p{Cf}"#,
            with: "",
            options: .regularExpression
        )
    }
}
