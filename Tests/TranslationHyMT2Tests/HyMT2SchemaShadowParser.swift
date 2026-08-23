import Foundation
@testable import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMT2SchemaShadowParser {
    static func probe(_ output: String, nonce: String) throws {
        do {
            let root = try object(output)
            guard Set(root.keys) == ["protocol_nonce"],
                root["protocol_nonce"] as? String == nonce
            else {
                throw HyMT2SchemaShadowFailureCode.probeFailed
            }
        } catch {
            throw HyMT2SchemaShadowFailureCode.probeFailed
        }
    }

    static func envelope(
        _ output: String,
        nonce: String,
        occurrences: [HyMT2SchemaShadowOccurrence]
    ) throws -> HyMT2SchemaShadowParsed {
        let root = try object(output)
        guard Set(root.keys) == ["protocol_nonce", "target_template", "bindings"] else {
            throw HyMT2SchemaShadowFailureCode.envelopeKeys
        }
        guard root["protocol_nonce"] as? String == nonce else {
            throw HyMT2SchemaShadowFailureCode.nonceMismatch
        }
        guard let template = root["target_template"] as? String else {
            throw HyMT2SchemaShadowFailureCode.envelopeJSON
        }
        guard !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HyMT2SchemaShadowFailureCode.targetEmpty
        }
        let bindings = try validatedBindings(root["bindings"], occurrences: occurrences)
        try validatePlaceholders(template, occurrences: occurrences)
        let target = reconstruct(template, occurrences: occurrences, bindings: bindings)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { throw HyMT2SchemaShadowFailureCode.targetEmpty }
        try rejectResidualProtocol(target)
        return HyMT2SchemaShadowParsed(
            targetTemplate: template,
            target: target,
            bindings: bindings
        )
    }
}
