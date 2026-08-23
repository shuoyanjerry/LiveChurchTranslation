import Foundation

struct NegationPolicyV2ShadowConfiguration {
    static let optInKey = "HYMT_NEGATION_POLICY_V2_OFFLINE_SHADOW"
    static let manifestKey = "BILINGUAL_TRANSLATION_MANIFEST"
    static let classifiedReportKey = "BILINGUAL_TRANSLATION_CLASSIFIED_REPORT"
    static let outputFilename = "negation-policy-v2-shadow-v1.json"

    let workspaceRoot: URL
    let manifestURL: URL
    let classifiedReportURL: URL

    static func isRequested(_ environment: [String: String]) -> Bool {
        environment[optInKey] != nil
    }

    static func load(_ environment: [String: String]) throws -> Self? {
        guard let optIn = environment[optInKey] else { return nil }
        guard optIn == "1" else { throw NegationPolicyV2ShadowError.invalidConfiguration }
        let workspace = URL(
            fileURLWithPath: environment["TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"]
                ?? FileManager.default.currentDirectoryPath,
            isDirectory: true
        ).resolvingSymlinksInPath().standardizedFileURL
        let manifest = try inputURL(manifestKey, environment: environment, root: workspace)
        let classified = try inputURL(
            classifiedReportKey,
            environment: environment,
            root: workspace
        )
        let output = outputURL(workspaceRoot: workspace)
        guard manifest != output, classified != output else {
            throw NegationPolicyV2ShadowError.invalidConfiguration
        }
        return Self(
            workspaceRoot: workspace,
            manifestURL: manifest,
            classifiedReportURL: classified
        )
    }

    static func outputURL(workspaceRoot: URL) -> URL {
        workspaceRoot
            .appendingPathComponent(".artifacts/translation-qualification", isDirectory: true)
            .appendingPathComponent(outputFilename)
            .standardizedFileURL
    }

    private static func inputURL(
        _ key: String,
        environment: [String: String],
        root: URL
    ) throws -> URL {
        guard let path = environment[key], !path.isEmpty else {
            throw NegationPolicyV2ShadowError.invalidConfiguration
        }
        let url = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath().standardizedFileURL
        let prefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard url.path.hasPrefix(prefix) else {
            throw NegationPolicyV2ShadowError.invalidConfiguration
        }
        return url
    }
}
