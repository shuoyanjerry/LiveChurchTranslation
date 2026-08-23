import Foundation

enum ScriptureManifestShapeValidator {
    static func validate(_ data: Data) throws {
        let value: Any
        do {
            value = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ScriptureQualificationError.malformedManifest
        }
        let root = try object(value, path: "$")
        try exactKeys(
            root,
            allowed: [
                "schemaVersion", "corpusID", "createdAt", "visibility", "mustNotCommit",
                "editionPair", "grants", "items", "translationPairs",
            ],
            path: "$"
        )
        try validateEditionPair(root["editionPair"])
        try array(root["grants"], path: "$.grants").enumerated().forEach {
            try validateGrant($0.element, path: "$.grants[\($0.offset)]")
        }
        try array(root["items"], path: "$.items").enumerated().forEach {
            try validateItem($0.element, path: "$.items[\($0.offset)]")
        }
        try array(root["translationPairs"], path: "$.translationPairs").enumerated().forEach {
            let path = "$.translationPairs[\($0.offset)]"
            try exactKeys(
                try object($0.element, path: path),
                allowed: ["id", "englishItemID", "simplifiedChineseItemID"],
                path: path
            )
        }
    }

    private static func validateEditionPair(_ value: Any?) throws {
        let pair = try object(value, path: "$.editionPair")
        try exactKeys(pair, allowed: ["english", "simplifiedChinese"], path: "$.editionPair")
        try validateEdition(pair["english"], path: "$.editionPair.english")
        try validateEdition(pair["simplifiedChinese"], path: "$.editionPair.simplifiedChinese")
    }

    private static func validateEdition(_ value: Any?, path: String) throws {
        try exactKeys(
            try object(value, path: path),
            allowed: [
                "id", "fullName", "abbreviation", "languageTag", "editionLabel",
                "publicationYear", "officialEditionReference", "rightsAdministrator",
            ],
            path: path
        )
    }

    private static func validateGrant(_ value: Any, path: String) throws {
        let grant = try object(value, path: path)
        try exactKeys(
            grant,
            allowed: [
                "id", "editionID", "licensor", "licensee", "agreementID", "evidencePath",
                "evidenceSHA256", "validFrom", "expiresAt", "territories", "reviewedBy",
                "reviewedAt", "rights",
            ],
            path: path
        )
        try exactKeys(
            try object(grant["rights"], path: "\(path).rights"),
            allowed: [
                "textUseAuthorized", "audioUseAuthorized", "recordingUseAuthorized",
                "asrEvaluationAuthorized", "crossLanguageEvaluationAuthorized",
                "modelTrainingAuthorized", "redistributionAuthorized",
            ],
            path: "\(path).rights"
        )
    }

    private static func validateItem(_ value: Any, path: String) throws {
        try exactKeys(
            try object(value, path: path),
            allowed: [
                "id", "editionID", "textGrantID", "audioGrantID", "useKind", "partition",
                "readingKind", "languageTag", "audioPath", "audioSHA256", "referencePath",
                "referenceSHA256", "bookID", "chapter", "verseStart", "verseEnd", "speakerID",
                "recordingEnvironment",
            ],
            path: path
        )
    }

    private static func exactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        path: String
    ) throws {
        let unknown = Set(object.keys).subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            throw ScriptureQualificationError.unknownJSONFields(path: path, fields: unknown)
        }
    }

    private static func object(_ value: Any?, path: String) throws -> [String: Any] {
        guard let result = value as? [String: Any] else {
            throw ScriptureQualificationError.invalidManifest("expected object at \(path)")
        }
        return result
    }

    private static func array(_ value: Any?, path: String) throws -> [Any] {
        guard let result = value as? [Any] else {
            throw ScriptureQualificationError.invalidManifest("expected array at \(path)")
        }
        return result
    }
}
