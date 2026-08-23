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
        let withoutFormatCharacters = removingFormatCharacters(from: value)
        return removingFormatCharacters(
            from: withoutFormatCharacters.precomposedStringWithCompatibilityMapping
        )
    }

    private static func removingFormatCharacters(from value: String) -> String {
        value.replacingOccurrences(
            of: #"\p{Cf}"#,
            with: "",
            options: .regularExpression
        )
    }
}
