import Foundation

enum HyMT2SchemaShadowConfigurationIdentity {
    static func sha256() throws -> String {
        let identity = Identity(
            protocolVersion: 1,
            allowedSchemaKeywords: [
                "additionalProperties", "const", "enum", "properties", "required", "type",
            ],
            variants: HyMT2SchemaShadowVariant.allCases,
            fixtures: try fixtureItems(),
            decoding: Decoding()
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(identity)
        return HyMT2SchemaShadowHash.sha256(data)
    }

    private static func fixtureItems() throws -> [Item] {
        var items: [Item] = []
        for (index, fixture) in HyMT2SchemaShadowFixtures.negation.enumerated() {
            let plan = try HyMT2SchemaShadowPlanBuilder.negation(fixture, index: index)
            let current = try HyMT2SchemaShadowCurrentProtocol.negationPlan(
                fixture,
                index: index
            )
            items.append(
                item(
                    plan,
                    currentPrompt: HyMT2SchemaShadowCurrentProtocol.negationPrompt(current)
                )
            )
        }
        for (index, fixture) in HyMT2SchemaShadowFixtures.pronoun.enumerated() {
            let plan = try HyMT2SchemaShadowPlanBuilder.pronoun(fixture, index: index)
            let current = try HyMT2SchemaShadowCurrentProtocol.pronounPlan(
                fixture,
                index: index
            )
            items.append(
                item(
                    plan,
                    currentPrompt: HyMT2SchemaShadowCurrentProtocol.pronounPrompt(
                        current,
                        source: fixture.base.source
                    )
                )
            )
        }
        return items
    }

    private static func item(
        _ plan: HyMT2SchemaShadowPlan,
        currentPrompt: String
    ) -> Item {
        Item(
            id: plan.fixtureID,
            family: plan.family,
            sourceSHA256: hash(plan.source),
            currentPromptSHA256: hash(currentPrompt),
            schemaPromptSHA256: hash(plan.prompt),
            occurrences: plan.occurrences.map {
                Occurrence(
                    id: $0.identifier,
                    allowedSurfaces: $0.allowedSurfaces,
                    expectedSurfaces: $0.expectedSurfaces.sorted(),
                    anchors: $0.anchorAlternatives,
                    resolution: $0.resolution?.rawValue
                )
            },
            globalAnchors: plan.globalAnchorGroups
        )
    }

    private static func hash(_ value: String) -> String {
        HyMT2NegationShadowFileHasher.sha256UTF8(value)
    }

    private struct Identity: Encodable {
        let protocolVersion: Int
        let allowedSchemaKeywords: [String]
        let variants: [HyMT2SchemaShadowVariant]
        let fixtures: [Item]
        let decoding: Decoding
    }

    private struct Decoding: Encodable {
        let seed = HyMT2NegationShadowQ4Settings.seed
        let temperature = HyMT2NegationShadowQ4Settings.temperature
        let topP = HyMT2NegationShadowQ4Settings.topP
        let topK = HyMT2NegationShadowQ4Settings.topK
        let repetitionPenalty = HyMT2NegationShadowQ4Settings.repetitionPenalty
        let threadCount = HyMT2NegationShadowQ4Settings.threadCount
        let contextSize = HyMT2NegationShadowQ4Settings.contextSize
        let maximumTokens = HyMT2NegationShadowQ4Settings.maximumTokens
    }

    private struct Item: Encodable {
        let id: String
        let family: HyMT2SchemaShadowFamily
        let sourceSHA256: String
        let currentPromptSHA256: String
        let schemaPromptSHA256: String
        let occurrences: [Occurrence]
        let globalAnchors: [[String]]
    }

    private struct Occurrence: Encodable {
        let id: String
        let allowedSurfaces: [String]
        let expectedSurfaces: [String]
        let anchors: [String]
        let resolution: String?
    }
}
