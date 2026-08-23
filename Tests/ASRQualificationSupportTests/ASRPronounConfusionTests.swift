import ASRQualificationSupport
import Foundation
import Testing

@Suite("ASR qualification pronoun confusion")
struct ASRPronounConfusionTests {
    @Test("counts correct and substituted pronouns")
    func correctAndSubstitution() {
        let confusion = measure("甲他她它祂乙", "甲他它它她乙")

        #expect(confusion.referenceTotal == 4)
        #expect(confusion.hypothesisTotal == 4)
        #expect(confusion.correctTotal == 2)
        #expect(confusion.substitutionTotal == 2)
        #expect(confusion.deletionTotal == 0)
        #expect(confusion.insertionTotal == 0)
        #expect(confusion.count(reference: "他", hypothesis: "他") == 1)
        #expect(confusion.count(reference: "她", hypothesis: "它") == 1)
        #expect(confusion.count(reference: "祂", hypothesis: "她") == 1)
    }

    @Test("full alignment does not cancel displaced equal pronouns")
    func displacedPronoun() {
        let confusion = measure("他甲", "甲他")

        #expect(confusion.correctTotal == 0)
        #expect(confusion.deletionTotal == 1)
        #expect(confusion.insertionTotal == 1)
        #expect(confusion.count(reference: "他", hypothesis: nil) == 1)
        #expect(confusion.count(reference: nil, hypothesis: "他") == 1)
    }

    @Test("counts hypothesis-only pronouns when reference has none")
    func insertionWithoutReferencePronoun() {
        let confusion = measure("救恩", "救她恩")

        #expect(confusion.referenceTotal == 0)
        #expect(confusion.hypothesisTotal == 1)
        #expect(confusion.insertionTotal == 1)
        #expect(confusion.count(reference: nil, hypothesis: "她") == 1)
    }

    @Test("counts strict prefix and suffix pronoun insertions")
    func edgeInsertions() {
        let confusion = measure("甲他乙", "她甲他乙祂")

        #expect(confusion.referenceTotal == 1)
        #expect(confusion.hypothesisTotal == 3)
        #expect(confusion.correctTotal == 1)
        #expect(confusion.insertionTotal == 2)
        #expect(confusion.count(reference: nil, hypothesis: "她") == 1)
        #expect(confusion.count(reference: nil, hypothesis: "祂") == 1)
    }

    @Test("counts pronoun deletion against a non-pronoun substitution")
    func pronounDeletion() {
        let confusion = measure("甲它乙", "甲人乙")

        #expect(confusion.referenceTotal == 1)
        #expect(confusion.hypothesisTotal == 0)
        #expect(confusion.deletionTotal == 1)
        #expect(confusion.count(reference: "它", hypothesis: nil) == 1)
    }

    @Test("zero-pronoun text produces an empty confusion")
    func zeroPronouns() {
        let confusion = measure("救恩本乎恩典", "救恩出于恩典")

        #expect(confusion.pairs.isEmpty)
        #expect(confusion.referenceTotal == 0)
        #expect(confusion.hypothesisTotal == 0)
        #expect(confusion.correctTotal == 0)
        #expect(confusion.substitutionTotal == 0)
        #expect(confusion.deletionTotal == 0)
        #expect(confusion.insertionTotal == 0)
    }

    @Test("confusion and pair counts are report-codable")
    func codableConfusion() throws {
        let confusion = measure("他她", "他它")

        let data = try JSONEncoder().encode(confusion)
        let decoded = try JSONDecoder().decode(ASRPronounConfusion.self, from: data)

        #expect(decoded == confusion)
        #expect(Set(decoded.pairs).count == decoded.pairs.count)
    }

    private func measure(_ reference: String, _ hypothesis: String) -> ASRPronounConfusion {
        ASRQualificationTextMetrics.normalizedStrictPronounConfusion(
            reference: reference,
            hypothesis: hypothesis
        )
    }
}
