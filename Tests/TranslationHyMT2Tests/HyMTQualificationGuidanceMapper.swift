import DiscourseResolutionAPI
import TranslationAPI
import TranslationQualificationSupport

enum HyMTQualificationGuidanceMapper {
    static func translationGuidance(
        _ values: [DiscoursePronounGuidance]
    ) -> [TranslationPronounGuidance] {
        values.map { value in
            TranslationPronounGuidance(
                sourceRange: TranslationSourceRange(
                    location: value.range.location,
                    length: value.range.length
                ),
                resolution: translationResolution(value.resolution)
            )
        }
    }

    static func observations(
        segment: TranslationQualificationSegment,
        guidance: [TranslationPronounGuidance]
    ) -> [TranslationGuidanceObservation] {
        let byLocation = Dictionary(
            uniqueKeysWithValues: guidance.map {
                ($0.sourceRange.location, $0.resolution.rawValue)
            })
        return segment.pronounOccurrences.map { occurrence in
            TranslationGuidanceObservation(
                occurrenceID: occurrence.id,
                resolution: byLocation[
                    utf16Location(
                        scalarOffset: occurrence.unicodeScalarOffset,
                        in: segment.observedASRAmbiguousChinese
                    )]
            )
        }
    }

    private static func translationResolution(
        _ value: DiscoursePronounResolution
    ) -> TranslationPronounResolution {
        switch value {
        case .unresolved:
            .unresolvedSpokenMandarin
        case .verified(let gender, _, _, _):
            gender == .female ? .verifiedFemale : .verifiedMale
        case .verifiedDeity:
            .verifiedDeity
        }
    }

    private static func utf16Location(scalarOffset: Int, in text: String) -> Int {
        let scalars = text.unicodeScalars
        let index = scalars.index(scalars.startIndex, offsetBy: scalarOffset)
        return String(scalars[..<index]).utf16.count
    }
}
