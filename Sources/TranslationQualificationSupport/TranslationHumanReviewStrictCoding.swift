import Foundation

struct TranslationHumanReviewCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

func requireExactHumanReviewKeys(
    _ decoder: Decoder,
    _ expected: Set<String>
) throws {
    let container = try decoder.container(keyedBy: TranslationHumanReviewCodingKey.self)
    let actual = Set(container.allKeys.map(\.stringValue))
    guard actual == expected else {
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "human review evidence has missing or unknown fields"
            )
        )
    }
}
