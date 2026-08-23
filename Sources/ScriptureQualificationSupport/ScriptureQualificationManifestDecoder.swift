import Foundation

public enum ScriptureQualificationManifestDecoder {
    public static func decode(_ data: Data) throws -> ScriptureQualificationManifest {
        try ScriptureStrictJSONValidator.validate(data)
        try ScriptureManifestShapeValidator.validate(data)
        do {
            return try JSONDecoder().decode(ScriptureQualificationManifest.self, from: data)
        } catch let error as ScriptureQualificationError {
            throw error
        } catch {
            throw ScriptureQualificationError.invalidManifest("schema decoding failed")
        }
    }
}
