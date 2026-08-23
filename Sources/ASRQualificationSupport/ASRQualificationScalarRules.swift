enum ASRQualificationScalarRules {
    static func validateHash(_ value: String, path: String) throws {
        let isLowercaseHex = value.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
        guard value.utf8.count == 64, isLowercaseHex else {
            throw ASRQualificationError.invalidSHA256(path: path)
        }
    }

    static func isBlank(_ value: String) -> Bool {
        value.isEmpty || value.allSatisfy { $0.isWhitespace }
    }
}

enum ASRQualificationProvenanceRules {
    static func validate(_ provenance: ASRQualificationProvenanceV2) throws {
        for (path, value) in hashes(provenance) {
            try ASRQualificationScalarRules.validateHash(value, path: path)
        }
        guard !ASRQualificationScalarRules.isBlank(provenance.sourceVADStrategy) else {
            throw ASRQualificationError.emptyProvenanceField("sourceVADStrategy")
        }
        guard !ASRQualificationScalarRules.isBlank(provenance.generatorRevision) else {
            throw ASRQualificationError.emptyProvenanceField("generatorRevision")
        }
    }

    private static func hashes(
        _ provenance: ASRQualificationProvenanceV2
    ) -> [(String, String)] {
        [
            ("provenance.sourceVADReportSHA256", provenance.sourceVADReportSHA256),
            (
                "provenance.sourceVADConfigurationSHA256",
                provenance.sourceVADConfigurationSHA256
            ),
            (
                "provenance.sourceReferenceManifestSHA256",
                provenance.sourceReferenceManifestSHA256
            ),
            (
                "provenance.sourceCorpusManifestSHA256",
                provenance.sourceCorpusManifestSHA256
            ),
        ]
    }
}
