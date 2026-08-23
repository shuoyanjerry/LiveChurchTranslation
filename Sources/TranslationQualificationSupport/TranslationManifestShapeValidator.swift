import Foundation

enum TranslationManifestShapeValidator {
    static func validate(_ data: Data) throws {
        let raw: Any
        do {
            raw = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TranslationQualificationError.invalidJSON("malformed JSON")
        }
        let root = try JSONShape.object(raw, path: "$root")
        try JSONShape.exactKeys(rootKeys, in: root, path: "$root")
        try validateSimpleObjects(root)
        try validateProfiles(root["referenceProfiles"] as Any)
        try validateSources(root["sources"] as Any)
        try validateSegments(root["segments"] as Any)
        try CandidateShapeValidator.validate(root["candidateSources"] as Any)
        try validateSummary(root["summary"] as Any)
    }

    private static func validateSimpleObjects(_ root: [String: Any]) throws {
        let provenance = try JSONShape.object(root["provenance"] as Any, path: "provenance")
        try JSONShape.exactKeys(provenanceKeys, in: provenance, path: "provenance")
        let policy = try JSONShape.object(root["policy"] as Any, path: "policy")
        try JSONShape.exactKeys(policyKeys, in: policy, path: "policy")
    }

    private static func validateProfiles(_ value: Any) throws {
        for (index, profile) in try JSONShape.objects(value, path: "referenceProfiles").enumerated() {
            try JSONShape.exactKeys(profileKeys, in: profile, path: "referenceProfiles[\(index)]")
        }
    }

    private static func validateSources(_ value: Any) throws {
        for (index, source) in try JSONShape.objects(value, path: "sources").enumerated() {
            let path = "sources[\(index)]"
            try JSONShape.exactKeys(sourceKeys, in: source, path: path)
            let rights = try JSONShape.object(source["rights"] as Any, path: "\(path).rights")
            try JSONShape.exactKeys(rightsKeys, in: rights, path: "\(path).rights")
        }
    }

    private static func validateSegments(_ value: Any) throws {
        for (index, segment) in try JSONShape.objects(value, path: "segments").enumerated() {
            let path = "segments[\(index)]"
            try JSONShape.exactKeys(segmentKeys, in: segment, path: path)
            try validateNestedSegment(segment, path: path)
        }
    }

    private static func validateNestedSegment(_ segment: [String: Any], path: String) throws {
        let locator = try JSONShape.object(segment["locator"] as Any, path: "\(path).locator")
        try JSONShape.exactKeys(locatorKeys, in: locator, path: "\(path).locator")
        let qualification = try JSONShape.object(
            segment["qualification"] as Any,
            path: "\(path).qualification"
        )
        try JSONShape.exactKeys(qualificationKeys, in: qualification, path: "\(path).qualification")
        for (index, occurrence) in try JSONShape.objects(
            segment["pronounOccurrences"] as Any,
            path: "\(path).pronounOccurrences"
        ).enumerated() {
            try JSONShape.exactKeys(
                occurrenceKeys,
                in: occurrence,
                path: "\(path).pronounOccurrences[\(index)]"
            )
        }
    }

    private static func validateSummary(_ value: Any) throws {
        let summary = try JSONShape.object(value, path: "summary")
        try JSONShape.exactKeys(summaryKeys, in: summary, path: "summary")
        for key in ["sourcePairCounts", "featureTagCounts", "pronounGuidanceCounts"] {
            let items = try JSONShape.objects(summary[key] as Any, path: "summary.\(key)")
            for (index, item) in items.enumerated() {
                let allowed = Set([
                    "count",
                    key == "sourcePairCounts" ? "sourceID" : key == "featureTagCounts" ? "tag" : "guidance",
                ])
                try JSONShape.exactKeys(allowed, in: item, path: "summary.\(key)[\(index)]")
            }
        }
    }

}
