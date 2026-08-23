import Foundation

enum StrictJSONShape {
    static func rootObject(_ data: Data, source: String) throws -> [String: Any] {
        try ManifestToolJSONDuplicateKeyValidator.validate(data, source: source)
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ManifestToolError.malformedInput(source)
        }
        return try object(value, path: source)
    }

    static func object(_ value: Any?, path: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw ManifestToolError.invalidValue(path: path)
        }
        return object
    }

    static func array(_ value: Any?, path: String) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw ManifestToolError.invalidValue(path: path)
        }
        return array
    }

    static func exact(
        _ object: [String: Any],
        keys: [String],
        path: String
    ) throws {
        let expected = Set(keys)
        if let field = object.keys.sorted().first(where: { !expected.contains($0) }) {
            throw ManifestToolError.unexpectedField(path: path, field: field)
        }
        if let field = keys.first(where: { object[$0] == nil }) {
            throw ManifestToolError.missingField(path: path, field: field)
        }
    }
}

enum StrictInputDecoder {
    static func vadReport(_ data: Data) throws -> VADReport {
        try VADInputShape.validate(data)
        let report: VADReport = try decode(data, source: "vad")
        guard report.schemaVersion == 1 else {
            throw ManifestToolError.unsupportedSchema(
                source: "vad",
                version: report.schemaVersion
            )
        }
        return report
    }

    static func corpusManifest(_ data: Data) throws -> CorpusManifest {
        try SourceInputShape.validateCorpus(data)
        let manifest: CorpusManifest = try decode(data, source: "corpus")
        try requireV1(manifest.schemaVersion, source: "corpus")
        return manifest
    }

    static func referenceManifest(_ data: Data) throws -> ReferenceManifest {
        try SourceInputShape.validateReference(data)
        let manifest: ReferenceManifest = try decode(data, source: "reference")
        try requireV1(manifest.schemaVersion, source: "reference")
        return manifest
    }

    private static func decode<T: Decodable>(
        _ data: Data,
        source: String
    ) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ManifestToolError.malformedInput(source)
        }
    }

    private static func requireV1(_ version: Int, source: String) throws {
        guard version == 1 else {
            throw ManifestToolError.unsupportedSchema(source: source, version: version)
        }
    }
}
