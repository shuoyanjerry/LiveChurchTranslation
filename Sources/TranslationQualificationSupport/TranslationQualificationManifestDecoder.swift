import Foundation

public enum TranslationQualificationManifestDecoder {
    public static func decode(_ data: Data) throws -> TranslationQualificationManifest {
        try TranslationJSONDuplicateKeyValidator.validate(data)
        try TranslationManifestShapeValidator.validate(data)
        do {
            return try JSONDecoder().decode(TranslationQualificationManifest.self, from: data)
        } catch {
            throw TranslationQualificationError.invalidJSON("manifest values do not match schema")
        }
    }
}
