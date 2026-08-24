import Foundation
import TranslationQualificationSupport

struct HyMTNegationDiagnosticConfiguration {
    static let optInKey = "HYMT_PRIVATE_NEGATION_DIAGNOSTIC"
    static let requiredEnvironmentKeys = [
        "HYMT_MODEL_DIR", "HYMT_LLAMA_SERVER", "BILINGUAL_TRANSLATION_MANIFEST",
        "BILINGUAL_TRANSLATION_CLASSIFIED_REPORT", "BILINGUAL_NEGATION_DIAGNOSTIC_REPORT",
    ]

    let workspaceRoot: URL
    let manifestURL: URL
    let classifiedReportURL: URL
    let reportFilename: String
    let modelURL: URL
    let helperURL: URL
    let backgroundLoad: String

    static func isRequested(_ environment: [String: String]) -> Bool {
        environment[optInKey] == "1"
    }

    static func load(_ environment: [String: String]) throws -> Self? {
        guard let optIn = environment[optInKey] else { return nil }
        guard optIn == "1" else { throw invalid("private diagnostic opt-in must equal 1") }
        guard requiredEnvironmentKeys.allSatisfy({ !(environment[$0] ?? "").isEmpty }) else {
            throw invalid("private negation diagnostic environment is incomplete")
        }
        let workspace = URL(
            fileURLWithPath: environment["TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"]
                ?? FileManager.default.currentDirectoryPath,
            isDirectory: true
        ).resolvingSymlinksInPath().standardizedFileURL
        let manifest = try workspaceInput("BILINGUAL_TRANSLATION_MANIFEST", environment, workspace)
        let classified = try workspaceInput(
            "BILINGUAL_TRANSLATION_CLASSIFIED_REPORT",
            environment,
            workspace
        )
        let filename = try required("BILINGUAL_NEGATION_DIAGNOSTIC_REPORT", environment)
        try TranslationQualificationReportWriter.validatePrivateFilename(filename)
        try rejectInputOverwrite(
            filename: filename,
            workspace: workspace,
            inputs: [manifest, classified]
        )
        return Self(
            workspaceRoot: workspace,
            manifestURL: manifest,
            classifiedReportURL: classified,
            reportFilename: filename,
            modelURL: URL(fileURLWithPath: try required("HYMT_MODEL_DIR", environment)),
            helperURL: URL(fileURLWithPath: try required("HYMT_LLAMA_SERVER", environment)),
            backgroundLoad: environment["TRANSLATION_QUALIFICATION_BACKGROUND_LOAD"]
                ?? "uncontrolled-user-session"
        )
    }

    var qualificationConfiguration: HyMTQualificationConfiguration {
        HyMTQualificationConfiguration(
            workspaceRoot: workspaceRoot,
            manifestURL: manifestURL,
            reportFilename: reportFilename,
            reviewPacketFilename: "synthetic-negation.review-packet.json",
            freezeRequestFilename: "synthetic-negation.freeze-request.json",
            modelURL: modelURL,
            helperURL: helperURL,
            backgroundLoad: backgroundLoad,
            expectedSourceBundleSHA256: String(repeating: "0", count: 64),
            expectedTestExecutableSHA256: String(repeating: "0", count: 64)
        )
    }

    private static func workspaceInput(
        _ key: String,
        _ environment: [String: String],
        _ workspace: URL
    ) throws -> URL {
        let value = URL(fileURLWithPath: try required(key, environment))
            .resolvingSymlinksInPath().standardizedFileURL
        let prefix = workspace.path.hasSuffix("/") ? workspace.path : workspace.path + "/"
        guard value.path.hasPrefix(prefix) else {
            throw TranslationQualificationError.unsafePath("private diagnostic input leaves workspace")
        }
        return value
    }

    private static func required(
        _ key: String,
        _ environment: [String: String]
    ) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw invalid("missing private diagnostic environment key")
        }
        return value
    }

    private static func rejectInputOverwrite(
        filename: String,
        workspace: URL,
        inputs: [URL]
    ) throws {
        let destination =
            workspace
            .appendingPathComponent(".artifacts/translation-qualification", isDirectory: true)
            .appendingPathComponent(filename)
            .standardizedFileURL
        guard !inputs.contains(where: { $0.standardizedFileURL.path == destination.path }) else {
            throw TranslationQualificationError.unsafePath(
                "private diagnostic output would overwrite an input"
            )
        }
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidManifest(message)
    }
}
