import Foundation
import Testing

@Suite("Hy-MT2 schema-shadow parser gates")
struct HyMT2SchemaShadowParserTests {
    @Test("strictly parses and deterministically rebuilds a valid envelope")
    func parsesValidEnvelope() throws {
        let parsed = try HyMT2SchemaShadowParser.envelope(
            output(template: "The sister said {{P0001}} would pray.", surface: "she"),
            nonce: nonce,
            occurrences: [occurrence]
        )

        #expect(parsed.target == "The sister said she would pray.")
        #expect(parsed.bindings == ["P0001": .init(surface: "she")])
    }

    @Test("rejects malformed or semantically invalid envelopes")
    func rejectsInvalidEnvelope() {
        for fixture in invalidCases {
            #expect(throws: fixture.failure, "\(fixture.testDescription)") {
                try HyMT2SchemaShadowParser.envelope(
                    fixture.output,
                    nonce: nonce,
                    occurrences: [occurrence]
                )
            }
        }
    }

    @Test("rejects adjacent placeholders even when each ID appears once")
    func rejectsAdjacentPlaceholders() {
        let second = HyMT2SchemaShadowOccurrence(
            identifier: "P0002",
            allowedSurfaces: ["he"],
            expectedSurfaces: ["he"],
            anchorAlternatives: ["pray"],
            resolution: .verifiedMale
        )
        let value = output(
            template: "The sister said {{P0001}}{{P0002}} would pray.",
            bindings: ["P0001": "she", "P0002": "he"]
        )

        #expect(throws: HyMT2SchemaShadowFailureCode.placeholderBoundary) {
            try HyMT2SchemaShadowParser.envelope(
                value,
                nonce: nonce,
                occurrences: [occurrence, second]
            )
        }
    }

    @Test("maps every malformed nonce probe to fail-closed probe failure")
    func probeFailsClosed() {
        #expect(throws: HyMT2SchemaShadowFailureCode.probeFailed) {
            try HyMT2SchemaShadowParser.probe("{}", nonce: nonce)
        }
        #expect(throws: HyMT2SchemaShadowFailureCode.probeFailed) {
            try HyMT2SchemaShadowParser.probe("not json", nonce: nonce)
        }
    }

    @Test("semantic oracle remains independent of structural acceptance")
    func semanticOracleRejectsWrongAnchor() throws {
        let parsed = try HyMT2SchemaShadowParser.envelope(
            output(template: "{{P0001}} left.", surface: "she"),
            nonce: nonce,
            occurrences: [occurrence]
        )
        let plan = semanticPlan(anchor: "pray")

        #expect(throws: HyMT2SchemaShadowFailureCode.semanticAnchor) {
            try HyMT2SchemaShadowSemanticOracle.validate(
                target: parsed.target,
                carrier: parsed.targetTemplate,
                tokens: ["P0001": "{{P0001}}"],
                bindings: parsed.bindings,
                plan: plan
            )
        }
    }
}

extension HyMT2SchemaShadowParserTests {
    private var nonce: String { "0123456789ABCDEF0123456789ABCDEF" }

    private var occurrence: HyMT2SchemaShadowOccurrence {
        HyMT2SchemaShadowOccurrence(
            identifier: "P0001",
            allowedSurfaces: ["she", "her"],
            expectedSurfaces: ["she", "her"],
            anchorAlternatives: ["pray"],
            resolution: .verifiedFemale
        )
    }

    private var invalidCases: [ParserFailureFixture] {
        [
            .init(output: duplicateNonce, failure: .envelopeJSON),
            .init(output: output(nonce: String(repeating: "F", count: 32)), failure: .nonceMismatch),
            .init(output: output(extraKey: true), failure: .envelopeKeys),
            .init(output: output(bindings: [:]), failure: .bindingKeys),
            .init(output: output(surface: "he"), failure: .bindingSurface),
            .init(output: output(template: "The sister would pray."), failure: .placeholderMissing),
            .init(output: output(template: "{{P0001}} and {{P0001}} pray."), failure: .placeholderDuplicate),
            .init(output: output(template: "{{P0001}} and {{P9999}} pray."), failure: .placeholderUnknown),
            .init(output: output(template: "s{{P0001}}he would pray."), failure: .placeholderBoundary),
            .init(output: output(template: "{{P0001}} <CURRENT_SOURCE> pray."), failure: .protocolResidual),
        ]
    }

    private var duplicateNonce: String {
        "{\"protocol_nonce\":\"\(nonce)\",\"protocol_nonce\":\"\(nonce)\","
            + "\"target_template\":\"{{P0001}} prays.\","
            + "\"bindings\":{\"P0001\":{\"surface\":\"she\"}}}"
    }

    private func output(
        template: String = "The sister said {{P0001}} would pray.",
        nonce: String? = nil,
        surface: String = "she",
        bindings: [String: String]? = nil,
        extraKey: Bool = false
    ) -> String {
        var root: [String: Any] = [
            "protocol_nonce": nonce ?? self.nonce,
            "target_template": template,
            "bindings": (bindings ?? ["P0001": surface]).mapValues { ["surface": $0] },
        ]
        if extraKey { root["extra"] = true }
        let data = try? JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func semanticPlan(anchor: String) -> HyMT2SchemaShadowPlan {
        var item = occurrence
        item = HyMT2SchemaShadowOccurrence(
            identifier: item.identifier,
            allowedSurfaces: item.allowedSurfaces,
            expectedSurfaces: item.expectedSurfaces,
            anchorAlternatives: [anchor],
            resolution: item.resolution
        )
        return HyMT2SchemaShadowPlan(
            fixtureID: "public.semantic",
            family: .pronoun,
            source: "public",
            prompt: "public",
            occurrences: [item],
            globalAnchorGroups: []
        )
    }
}

struct ParserFailureFixture: Sendable, CustomTestStringConvertible {
    let output: String
    let failure: HyMT2SchemaShadowFailureCode

    var testDescription: String { failure.rawValue }
}
