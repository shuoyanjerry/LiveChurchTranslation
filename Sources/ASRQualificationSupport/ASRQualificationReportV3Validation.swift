import Foundation

enum ASRQualificationReportV3Rules {
    static func validateHeader(
        generatedAt: Date,
        manifestSHA256: String,
        manifest: ASRQualificationManifestV2,
        provider: ASRQualificationProviderMetadataV3,
        environment: ASRQualificationEnvironmentV3
    ) throws {
        do {
            try ASRQualificationManifestValidator().validate(manifest)
        } catch let error as ASRQualificationError {
            throw ASRQualificationReportV3Error.invalidManifest(error)
        }
        guard generatedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw ASRQualificationReportV3Error.invalidGeneratedAt
        }
        guard isSHA256(manifestSHA256) else {
            throw ASRQualificationReportV3Error.invalidQualificationManifestSHA256
        }
        try validate(provider)
        try validate(environment)
    }

    static func indexInputs(
        _ inputs: [ASRQualificationClipEvaluationInputV3],
        manifest: ASRQualificationManifestV2
    ) throws -> [String: ASRQualificationClipEvaluationInputV3] {
        var indexed: [String: ASRQualificationClipEvaluationInputV3] = [:]
        for input in inputs {
            guard indexed.updateValue(input, forKey: input.id) == nil else {
                throw ASRQualificationReportV3Error.duplicateClipID(input.id)
            }
        }
        let expected = manifest.clips.map(\.id).sorted()
        let actual = indexed.keys.sorted()
        guard expected == actual else {
            throw ASRQualificationReportV3Error.clipSetMismatch(
                expected: expected,
                actual: actual
            )
        }
        return indexed
    }

    private static func validate(_ provider: ASRQualificationProviderMetadataV3) throws {
        for (field, value) in [
            ("provider.name", provider.name),
            ("provider.modelRevision", provider.modelRevision),
            ("provider.runtimeRevision", provider.runtimeRevision),
        ] where isBlank(value) {
            throw ASRQualificationReportV3Error.invalidProviderField(field)
        }
        guard provider.lane == "productionAdapter" else {
            throw ASRQualificationReportV3Error.invalidProviderLane(provider.lane)
        }
        if let key = provider.settings.keys.sorted().first(where: isBlank) {
            throw ASRQualificationReportV3Error.invalidSettingKey(key)
        }
        if let key = provider.settings.keys.sorted().first(where: {
            isBlank(provider.settings[$0] ?? "")
        }) {
            throw ASRQualificationReportV3Error.invalidSettingValue(key)
        }
    }

    private static func validate(_ environment: ASRQualificationEnvironmentV3) throws {
        let fields = [
            ("environment.os", environment.os),
            ("environment.hardware", environment.hardware),
            ("environment.architecture", environment.architecture),
            ("environment.buildConfiguration", environment.buildConfiguration),
            ("environment.repositoryRevision", environment.repositoryRevision),
            ("environment.backgroundLoadNote", environment.backgroundLoadNote),
        ]
        if let field = fields.first(where: { isBlank($0.1) })?.0 {
            throw ASRQualificationReportV3Error.invalidEnvironmentField(field)
        }
    }

    private static func isBlank(_ value: String) -> Bool {
        value.isEmpty || value.allSatisfy(\.isWhitespace)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.utf8.count == 64
            && value.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
    }
}
