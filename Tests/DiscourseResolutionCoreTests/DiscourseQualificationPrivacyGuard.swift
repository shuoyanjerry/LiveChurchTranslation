import Foundation
import TranslationQualificationSupport

enum DiscourseQualificationPrivacyGuard {
    private static let forbiddenFieldNames = [
        "originalChinese", "observedASRAmbiguousChinese", "referenceEnglish",
        "antecedentLabel", "resolvedText", "evidenceText",
    ]

    static func validate(
        _ data: Data,
        corpus: TranslationQualificationCorpus
    ) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        let emitted = Set(strings(in: object))
        let privateValues = Set(corpus.manifest.segments.flatMap(privateStrings))
        guard emitted.isDisjoint(with: privateValues) else { throw privacyError }
        guard let encoded = String(data: data, encoding: .utf8) else { throw privacyError }
        guard forbiddenFieldNames.allSatisfy({ !encoded.contains("\"\($0)\"") }) else {
            throw privacyError
        }
    }

    private static func privateStrings(
        _ segment: TranslationQualificationSegment
    ) -> [String] {
        [
            segment.originalChinese,
            segment.observedASRAmbiguousChinese,
            segment.referenceEnglish,
        ] + segment.pronounOccurrences.compactMap(\.antecedentLabel)
    }

    private static func strings(in value: Any) -> [String] {
        if let string = value as? String { return [string] }
        if let array = value as? [Any] { return array.flatMap(strings) }
        if let dictionary = value as? [String: Any] {
            return Array(dictionary.keys) + dictionary.values.flatMap(strings)
        }
        return []
    }

    private static var privacyError: TranslationQualificationError {
        .invalidReport("discourse qualification report contains private text")
    }
}
