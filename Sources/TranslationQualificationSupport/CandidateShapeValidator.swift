enum CandidateShapeValidator {
    static func validate(_ value: Any) throws {
        for (index, candidate) in try JSONShape.objects(value, path: "candidateSources").enumerated() {
            let path = "candidateSources[\(index)]"
            guard let provider = candidate["provider"] as? String else {
                throw TranslationQualificationError.invalidJSON("\(path).provider must be a string")
            }
            if provider == "Global Recordings Network" {
                try validateGRN(candidate, path: path)
            } else if provider == "Hesed" {
                try JSONShape.exactKeys(hesedKeys, in: candidate, path: path)
            } else {
                throw TranslationQualificationError.invalidJSON("\(path) has unknown provider")
            }
        }
    }

    private static func validateGRN(_ candidate: [String: Any], path: String) throws {
        try JSONShape.exactKeys(grnKeys, in: candidate, path: path)
        let files = try JSONShape.objects(candidate["localFiles"] as Any, path: "\(path).localFiles")
        for (index, file) in files.enumerated() {
            try JSONShape.exactKeys(localFileKeys, in: file, path: "\(path).localFiles[\(index)]")
        }
        let rights = try JSONShape.object(candidate["rights"] as Any, path: "\(path).rights")
        try JSONShape.exactKeys(candidateRightsKeys, in: rights, path: "\(path).rights")
    }

    private static let grnKeys = Set([
        "id", "provider", "sourceURLs", "localFiles", "matchingNumberedSectionCount", "decision",
        "referenceClass", "audioLinkage", "reason", "allowedQualification",
        "forbiddenQualification", "rights",
    ])
    private static let hesedKeys = Set([
        "id", "provider", "sourceURLs", "decision", "referenceClass", "reason",
    ])
    private static let localFileKeys = Set(["path", "sha256"])
    private static let candidateRightsKeys = Set([
        "license", "licenseURL", "mustNotCommitInThisProject",
    ])
}
