import Foundation

enum HyMT2PronounAlternativeListDetector {
    static func containsAlternativeList(in value: String) -> Bool {
        HyMT2ReservedProtocolText.inspectionForm(value).range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static let pronoun =
        "(?:he|him|his|himself|she|her|hers|herself|they|them|their|theirs|"
        + "themself|themselves)"
    private static let pattern =
        "(?:^|[^A-Za-z])" + pronoun
        + #"(?:\s*[/⁄∕|]\s*"# + pronoun + #"){2,}(?=$|[^A-Za-z])"#
}
