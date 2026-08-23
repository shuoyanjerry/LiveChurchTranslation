import Foundation
import Testing

@Suite("Hy-MT2 schema-shadow schema and wire gates")
struct HyMT2SchemaShadowSchemaTests {
    @Test("uses the exact non-empty OpenAI JSON Schema request shape")
    func usesNestedResponseFormat() throws {
        let nonce = "0123456789ABCDEF0123456789ABCDEF"
        let schema = try HyMT2SchemaShadowSchemaBuilder.envelope(
            nonce: nonce,
            occurrences: [sampleOccurrence]
        )
        let data = try HyMT2SchemaShadowWire.requestData(
            prompt: "public prompt with {{P0001}}",
            maximumTokens: 64,
            stop: ["public stop"],
            schema: schema,
            nonceAbsentFromPrompt: nonce
        )
        let root = try object(data)
        let format = try child("response_format", in: root)
        let definition = try child("json_schema", in: format)
        let encodedSchema = try child("schema", in: definition)

        #expect(format["type"] as? String == "json_schema")
        #expect(definition["strict"] as? Bool == true)
        #expect(!encodedSchema.isEmpty)
        #expect(try prompt(in: root).contains(nonce) == false)
        try validateAllowedKeywords(encodedSchema)
    }

    @Test("omits response_format from the current arm")
    func currentArmOmitsSchema() throws {
        let data = try HyMT2SchemaShadowWire.requestData(
            prompt: "public current prompt",
            maximumTokens: 64,
            stop: [],
            schema: nil,
            nonceAbsentFromPrompt: nil
        )
        let root = try object(data)

        #expect(root["response_format"] == nil)
    }

    @Test("supports an empty required-key bindings object")
    func permitsZeroOccurrences() throws {
        let schema = try HyMT2SchemaShadowSchemaBuilder.envelope(
            nonce: "FEDCBA9876543210FEDCBA9876543210",
            occurrences: []
        )
        let data = try HyMT2SchemaShadowSchemaBuilder.encoded(schema)
        let root = try object(data)
        let properties = try child("properties", in: root)
        let bindings = try child("bindings", in: properties)

        #expect((bindings["properties"] as? [String: Any])?.isEmpty == true)
        #expect((bindings["required"] as? [String])?.isEmpty == true)
        #expect(bindings["additionalProperties"] as? Bool == false)
    }

    @Test("rejects a nonce copied into the prompt before transport")
    func rejectsPromptNonce() throws {
        let nonce = "0123456789ABCDEF0123456789ABCDEF"
        let schema = try HyMT2SchemaShadowSchemaBuilder.probe(nonce: nonce)

        #expect(throws: HyMT2SchemaShadowFailureCode.schemaInvalid) {
            try HyMT2SchemaShadowWire.requestData(
                prompt: "copied \(nonce)",
                maximumTokens: 64,
                stop: [],
                schema: schema,
                nonceAbsentFromPrompt: nonce
            )
        }
    }

    private var sampleOccurrence: HyMT2SchemaShadowOccurrence {
        HyMT2SchemaShadowOccurrence(
            identifier: "P0001",
            allowedSurfaces: ["she", "her"],
            expectedSurfaces: ["she", "her"],
            anchorAlternatives: ["pray"],
            resolution: .verifiedFemale
        )
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func child(_ key: String, in value: [String: Any]) throws -> [String: Any] {
        try #require(value[key] as? [String: Any])
    }

    private func prompt(in root: [String: Any]) throws -> String {
        let messages = try #require(root["messages"] as? [[String: Any]])
        return try #require(messages.first?["content"] as? String)
    }

    private func validateAllowedKeywords(_ schema: [String: Any]) throws {
        let allowed: Set<String> = [
            "additionalProperties", "const", "enum", "properties", "required", "type",
        ]
        #expect(Set(schema.keys).isSubset(of: allowed))
        guard let properties = schema["properties"] as? [String: Any] else { return }
        for child in properties.values {
            try validateAllowedKeywords(try #require(child as? [String: Any]))
        }
    }
}
