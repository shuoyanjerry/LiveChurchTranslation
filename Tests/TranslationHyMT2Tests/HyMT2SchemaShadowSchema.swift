import Foundation

struct HyMT2SchemaShadowSchema: Codable, Equatable, Sendable {
    let type: String
    let properties: [String: Self]?
    let required: [String]?
    let additionalProperties: Bool?
    let constant: String?
    let enumeration: [String]?

    enum CodingKeys: String, CodingKey {
        case type, properties, required, additionalProperties
        case constant = "const"
        case enumeration = "enum"
    }

    static func object(
        _ properties: [String: Self],
        required: [String]
    ) -> Self {
        Self(
            type: "object",
            properties: properties,
            required: required,
            additionalProperties: false,
            constant: nil,
            enumeration: nil
        )
    }

    static func string(
        constant: String? = nil,
        enumeration: [String]? = nil
    ) -> Self {
        Self(
            type: "string",
            properties: nil,
            required: nil,
            additionalProperties: nil,
            constant: constant,
            enumeration: enumeration
        )
    }
}

enum HyMT2SchemaShadowSchemaBuilder {
    static func envelope(
        nonce: String,
        occurrences: [HyMT2SchemaShadowOccurrence]
    ) throws -> HyMT2SchemaShadowSchema {
        guard isNonce(nonce) else { throw HyMT2SchemaShadowFailureCode.schemaInvalid }
        let identifiers = occurrences.map(\.identifier)
        guard Set(identifiers).count == identifiers.count,
            identifiers.allSatisfy(isIdentifier),
            occurrences.allSatisfy(validSurfaces)
        else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        let bindings = Dictionary(
            uniqueKeysWithValues: occurrences.map { occurrence in
                (
                    occurrence.identifier,
                    HyMT2SchemaShadowSchema.object(
                        [
                            "surface": .string(
                                enumeration: occurrence.allowedSurfaces
                            )
                        ],
                        required: ["surface"]
                    )
                )
            }
        )
        let schema = HyMT2SchemaShadowSchema.object(
            [
                "protocol_nonce": .string(constant: nonce),
                "target_template": .string(),
                "bindings": .object(bindings, required: identifiers),
            ],
            required: ["protocol_nonce", "target_template", "bindings"]
        )
        try validateAllowlist(schema)
        return schema
    }

    static func probe(nonce: String) throws -> HyMT2SchemaShadowSchema {
        guard isNonce(nonce) else { throw HyMT2SchemaShadowFailureCode.schemaInvalid }
        return .object(
            ["protocol_nonce": .string(constant: nonce)],
            required: ["protocol_nonce"]
        )
    }

    static func encoded(_ schema: HyMT2SchemaShadowSchema) throws -> Data {
        try validateAllowlist(schema)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(schema)
    }

    private static func validateAllowlist(_ schema: HyMT2SchemaShadowSchema) throws {
        guard ["object", "string"].contains(schema.type) else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        if schema.type == "object" {
            guard let properties = schema.properties,
                schema.additionalProperties == false,
                let required = schema.required,
                required.count == Set(required).count,
                Set(required) == Set(properties.keys),
                schema.constant == nil, schema.enumeration == nil
            else {
                throw HyMT2SchemaShadowFailureCode.schemaInvalid
            }
            try properties.values.forEach(validateAllowlist)
        } else {
            guard schema.properties == nil, schema.required == nil,
                schema.additionalProperties == nil,
                !(schema.constant != nil && schema.enumeration != nil),
                schema.enumeration.map({ !$0.isEmpty && Set($0).count == $0.count }) ?? true
            else {
                throw HyMT2SchemaShadowFailureCode.schemaInvalid
            }
        }
    }

    private static func isIdentifier(_ value: String) -> Bool {
        value.range(of: #"^[PN][0-9]{4}$"#, options: .regularExpression) != nil
    }

    private static func isNonce(_ value: String) -> Bool {
        value.range(of: #"^[0-9A-F]{32}$"#, options: .regularExpression) != nil
    }

    private static func validSurfaces(_ occurrence: HyMT2SchemaShadowOccurrence) -> Bool {
        let values = occurrence.allowedSurfaces
        return !values.isEmpty && Set(values).count == values.count
            && values.allSatisfy {
                $0.range(
                    of: #"^[A-Za-z]+(?:'[A-Za-z]+)?$"#,
                    options: .regularExpression
                ) != nil
            }
    }
}
