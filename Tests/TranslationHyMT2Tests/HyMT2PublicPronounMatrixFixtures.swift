import Foundation
import TranslationAPI
@testable import TranslationHyMT2

struct PublicPronounFixture: Sendable {
    let name: String
    let source: String
    let references: [PublicPronounReference]

    func request(id: UUID) throws -> TranslationRequest {
        TranslationRequest(
            id: id,
            sourceText: source,
            glossary: [],
            pronounGuidance: try references.map { reference in
                TranslationPronounGuidance(
                    sourceRange: try sourceRange(for: reference),
                    resolution: reference.resolution
                )
            }
        )
    }

    func expectedTraces() throws -> [ExpectedPublicPronounTrace] {
        try references.map { reference in
            ExpectedPublicPronounTrace(
                sourceRange: try sourceRange(for: reference),
                resolution: reference.resolution,
                realization: reference.resolution.expectedRealization
            )
        }
    }

    private func sourceRange(
        for reference: PublicPronounReference
    ) throws -> TranslationSourceRange {
        let matches = source.indices.filter { source[$0] == reference.glyph }
        guard matches.indices.contains(reference.occurrence) else {
            throw PublicPronounFixtureError.missingOccurrence(name)
        }
        let index = matches[reference.occurrence]
        return TranslationSourceRange(
            location: index.utf16Offset(in: source),
            length: String(reference.glyph).utf16.count
        )
    }
}

struct PublicPronounReference: Sendable {
    let glyph: Character
    let occurrence: Int
    let resolution: TranslationPronounResolution
}

struct ExpectedPublicPronounTrace: Equatable, Sendable {
    let sourceRange: TranslationSourceRange
    let resolution: TranslationPronounResolution
    let realization: HyMT2PronounRealizationClass
}

enum PublicPronounFixtureError: Error {
    case missingOccurrence(String)
}

extension TranslationPronounResolution {
    fileprivate var expectedRealization: HyMT2PronounRealizationClass {
        switch self {
        case .unresolvedSpokenMandarin: .singularThey
        case .verifiedFemale: .feminine
        case .verifiedMale, .verifiedDeity: .masculine
        }
    }
}

enum HyMT2PublicPronounFixtures {
    static let all: [PublicPronounFixture] = [
        PublicPronounFixture(
            name: "standalone-unresolved",
            source: "他后来继续分享这个见证。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .unresolvedSpokenMandarin)
            ]
        ),
        PublicPronounFixture(
            name: "standalone-deity-resolved-glyph",
            source: "神爱世人。祂赐下独生子。",
            references: [
                .init(glyph: "祂", occurrence: 0, resolution: .verifiedDeity)
            ]
        ),
        PublicPronounFixture(
            name: "four-female-asr-glyphs",
            source: "他去过香港，因为他有亲人在新加坡。他知道我英文不好，但是他仍然努力和我交流。",
            references: (0..<4).map {
                .init(glyph: "他", occurrence: $0, resolution: .verifiedFemale)
            }
        ),
        PublicPronounFixture(
            name: "female-male-possessive",
            source: "姐妹说他会帮助他，也会为他的家人祷告。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedFemale),
                .init(glyph: "他", occurrence: 1, resolution: .verifiedMale),
                .init(glyph: "他", occurrence: 2, resolution: .verifiedMale),
            ]
        ),
        PublicPronounFixture(
            name: "female-unresolved",
            source: "他先作见证，然后他回应。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedFemale),
                .init(glyph: "他", occurrence: 1, resolution: .unresolvedSpokenMandarin),
            ]
        ),
        PublicPronounFixture(
            name: "deity-human",
            source: "神施恩。他安慰弟兄，后来他回应。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedDeity),
                .init(glyph: "他", occurrence: 1, resolution: .verifiedMale),
            ]
        ),
        PublicPronounFixture(
            name: "male-female",
            source: "弟兄说他会先祷告，然后他来读经。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedMale),
                .init(glyph: "他", occurrence: 1, resolution: .verifiedFemale),
            ]
        ),
        PublicPronounFixture(
            name: "object-and-female-possessive",
            source: "姐妹为他祷告，也把他的圣经还给他。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedMale),
                .init(glyph: "他", occurrence: 1, resolution: .verifiedFemale),
                .init(glyph: "他", occurrence: 2, resolution: .verifiedFemale),
            ]
        ),
        PublicPronounFixture(
            name: "deity-and-human-object",
            source: "弟兄感谢神，因为他安慰了他。",
            references: [
                .init(glyph: "他", occurrence: 0, resolution: .verifiedDeity),
                .init(glyph: "他", occurrence: 1, resolution: .verifiedMale),
            ]
        ),
    ]
}
