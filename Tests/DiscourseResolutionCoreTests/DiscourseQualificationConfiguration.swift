import Foundation
import TranslationQualificationSupport

struct DiscourseQualificationConfiguration {
    static let manifestSHA256 =
        "c9a084145ad7b575c77239c81f9c8f47919dff4ee9f3910f008fcb71ca5a2e50"
    static let schemaSHA256 =
        "865c5f8d7496112e9d634be98bd1ca0731d393b4c29d36a121ad52adb026d7d7"
    static let manifestKey = "BILINGUAL_TRANSLATION_MANIFEST"
    static let reportKey = "DISCOURSE_QUALIFICATION_REPORT"
    static let workspaceKey = "TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"

    let workspaceRoot: URL
    let manifestURL: URL
    let reportFilename: String

    static func isRequested(_ environment: [String: String]) -> Bool {
        environment[reportKey] != nil
    }

    static func load(_ environment: [String: String]) throws -> Self? {
        guard isRequested(environment) else { return nil }
        let manifestPath = try required(manifestKey, environment)
        let reportFilename = try required(reportKey, environment)
        try TranslationQualificationReportWriter.validatePrivateFilename(reportFilename)
        let workspacePath = environment[workspaceKey] ?? FileManager.default.currentDirectoryPath
        return Self(
            workspaceRoot: URL(fileURLWithPath: workspacePath, isDirectory: true),
            manifestURL: URL(fileURLWithPath: manifestPath, isDirectory: false),
            reportFilename: reportFilename
        )
    }

    private static func required(
        _ key: String,
        _ environment: [String: String]
    ) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw TranslationQualificationError.invalidManifest(
                "discourse qualification environment is incomplete"
            )
        }
        return value
    }
}
