import Foundation
import TranslationQualificationSupport

enum NegationPolicyV2ShadowIdentity {
    static func policySHA256(workspaceRoot: URL) throws -> String {
        let root = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let entries = try policyFiles.map { relativePath in
            let url = root.appendingPathComponent(relativePath)
                .resolvingSymlinksInPath().standardizedFileURL
            try validatePolicyFile(url, root: root)
            return PolicyFileDigest(
                relativePath: relativePath,
                sha256: try TranslationQualificationSHA256.hash(fileAt: url)
            )
        }
        return TranslationQualificationSHA256.hash(data: try canonicalData(entries))
    }

    static func configurationSHA256() throws -> String {
        let snapshot = ConfigurationSnapshot(
            revision: "negation-policy-v2-shadow-v1",
            sourceField: "translationSourceText",
            successTargetField: "hypothesisEnglish",
            failureTargetPolicy: "source-only-no-hypothesis-inference",
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedClassifiedReportSHA256: classifiedReportSHA256,
            expectedSegmentCount: 144,
            expectedSuccessCount: 109,
            expectedFailureCount: 35,
            outputFilename: NegationPolicyV2ShadowConfiguration.outputFilename
        )
        return TranslationQualificationSHA256.hash(data: try canonicalData(snapshot))
    }

    static let classifiedReportSHA256 =
        "7108b5bd53874da6446bb487a8c8d441c88bca1564214f77523418585cf51ff8"

    private static func validatePolicyFile(_ url: URL, root: URL) throws {
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard
            url.path.hasPrefix(prefix),
            values.isRegularFile == true,
            let bytes = values.fileSize,
            bytes <= 512 * 1_024
        else { throw NegationPolicyV2ShadowError.invalidConfiguration }
    }

    private static func canonicalData<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    private static let policyFiles = [
        "Tests/TranslationHyMT2Tests/NegationPolicyV2.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2Chinese.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2ChineseLexicalMask.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2ChineseLexicon.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2English.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2Types.swift",
        "Tests/TranslationHyMT2Tests/NegationPolicyV2Unicode.swift",
    ]
}

private struct PolicyFileDigest: Encodable {
    let relativePath: String
    let sha256: String
}

private struct ConfigurationSnapshot: Encodable {
    let revision: String
    let sourceField: String
    let successTargetField: String
    let failureTargetPolicy: String
    let expectedManifestSHA256: String
    let expectedClassifiedReportSHA256: String
    let expectedSegmentCount: Int
    let expectedSuccessCount: Int
    let expectedFailureCount: Int
    let outputFilename: String
}
