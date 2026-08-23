import Foundation
@testable import TranslationQualificationSupport

extension HyMT2SchemaShadowParser {
    static func object(_ output: String) throws -> [String: Any] {
        guard let data = output.data(using: .utf8) else {
            throw HyMT2SchemaShadowFailureCode.envelopeJSON
        }
        do {
            try TranslationJSONDuplicateKeyValidator.validate(data)
            guard
                let value = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                throw HyMT2SchemaShadowFailureCode.envelopeJSON
            }
            return value
        } catch let failure as HyMT2SchemaShadowFailureCode {
            throw failure
        } catch {
            throw HyMT2SchemaShadowFailureCode.envelopeJSON
        }
    }

    static func validatedBindings(
        _ value: Any?,
        occurrences: [HyMT2SchemaShadowOccurrence]
    ) throws -> [String: HyMT2SchemaShadowBinding] {
        guard let raw = value as? [String: Any] else {
            throw HyMT2SchemaShadowFailureCode.bindingShape
        }
        let expected = Set(occurrences.map(\.identifier))
        guard Set(raw.keys) == expected else {
            throw HyMT2SchemaShadowFailureCode.bindingKeys
        }
        var result: [String: HyMT2SchemaShadowBinding] = [:]
        for occurrence in occurrences {
            guard let item = raw[occurrence.identifier] as? [String: Any],
                Set(item.keys) == ["surface"],
                let surface = item["surface"] as? String
            else {
                throw HyMT2SchemaShadowFailureCode.bindingShape
            }
            guard occurrence.allowedSurfaces.contains(surface) else {
                throw HyMT2SchemaShadowFailureCode.bindingSurface
            }
            result[occurrence.identifier] = HyMT2SchemaShadowBinding(surface: surface)
        }
        return result
    }
}
