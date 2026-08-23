import Foundation

struct ScriptureModelQualificationConfiguration: Sendable {
    let privateRoot: URL
    let manifestURL: URL
    let manifestSHA256: String
    let qwenModelDirectory: URL
    let hyMTModelLocation: URL
    let hyMTHelperURL: URL
    let reportURL: URL
    let workspaceRoot: URL
    let phase: ScriptureQualificationPhase

    static func isRequested(_ environment: [String: String]) -> Bool {
        scriptureKeys.contains { environment[$0] != nil }
    }

    static func load(
        environment: [String: String],
        workspaceRoot: URL = repositoryRoot
    ) throws -> Self {
        guard environment["SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY"] == "1" else {
            throw ScriptureModelQualificationError.invalidEnvironment(
                "SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY"
            )
        }
        let root = try absoluteURL("SCRIPTURE_QUALIFICATION_ROOT", environment)
        let manifest = try absoluteURL("SCRIPTURE_QUALIFICATION_MANIFEST", environment)
        let manifestSHA = try requiredSHA(
            "SCRIPTURE_QUALIFICATION_MANIFEST_SHA256",
            environment
        )
        let report = try absoluteURL("SCRIPTURE_QUALIFICATION_REPORT", environment)
        try requireReportLocation(report, workspaceRoot: workspaceRoot)
        guard
            let phase = ScriptureQualificationPhase(
                rawValue: environment["SCRIPTURE_QUALIFICATION_PHASE"] ?? ""
            )
        else {
            throw ScriptureModelQualificationError.invalidEnvironment(
                "SCRIPTURE_QUALIFICATION_PHASE"
            )
        }
        return Self(
            privateRoot: root,
            manifestURL: manifest,
            manifestSHA256: manifestSHA,
            qwenModelDirectory: try absoluteURL("QWEN_MODEL_DIR", environment),
            hyMTModelLocation: try absoluteURL("HYMT_MODEL_DIR", environment),
            hyMTHelperURL: try absoluteURL("HYMT_LLAMA_SERVER", environment),
            reportURL: report,
            workspaceRoot: workspaceRoot.standardizedFileURL,
            phase: phase
        )
    }

    private static func absoluteURL(
        _ key: String,
        _ environment: [String: String]
    ) throws -> URL {
        guard let path = environment[key], path.hasPrefix("/") else {
            throw ScriptureModelQualificationError.invalidEnvironment(key)
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    private static func requiredSHA(
        _ key: String,
        _ environment: [String: String]
    ) throws -> String {
        guard let value = environment[key], isSHA256(value) else {
            throw ScriptureModelQualificationError.invalidEnvironment(key)
        }
        return value
    }

    private static func requireReportLocation(
        _ report: URL,
        workspaceRoot: URL
    ) throws {
        let expected = workspaceRoot.standardizedFileURL
            .appendingPathComponent(".artifacts/scripture-qualification-reports")
            .standardizedFileURL
        guard report.deletingLastPathComponent().path == expected.path,
            validReportFilename(report.lastPathComponent)
        else {
            throw ScriptureModelQualificationError.invalidEnvironment(
                "SCRIPTURE_QUALIFICATION_REPORT"
            )
        }
    }

    private static func validReportFilename(_ value: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        return value.count <= 128 && value.hasSuffix(".json") && !value.contains("..")
            && value.unicodeScalars.allSatisfy(allowed.contains)
    }

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private static let scriptureKeys = [
        "SCRIPTURE_QUALIFICATION_ROOT",
        "SCRIPTURE_QUALIFICATION_MANIFEST",
        "SCRIPTURE_QUALIFICATION_MANIFEST_SHA256",
    ]
}
