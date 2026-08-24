import Foundation
import TranslationQualificationSupport
@testable import TranslationHyMT2

struct HyMTQualificationConfiguration {
    static let requiredEnvironmentKeys = [
        "HYMT_MODEL_DIR", "HYMT_LLAMA_SERVER", "BILINGUAL_TRANSLATION_MANIFEST",
        "BILINGUAL_TRANSLATION_REPORT", "TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256",
        "TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256",
    ]
    static let manifestSHA256 =
        "d63632efc67e9e5fb88a1dbc063cf796e079b6cbbd115320a989ff53ff2fc7bb"
    static let schemaSHA256 = "865c5f8d7496112e9d634be98bd1ca0731d393b4c29d36a121ad52adb026d7d7"
    static let modelSHA256 = "dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699"
    static let modelRevision = "1cd5208700acedef4ef93019b6cfc148b8522d45"
    static let runtimeRevision = "b10549"
    static let helperSHA256 = "d0878274b8d6bd3c8ea26a78eb66cd1ffd943d007c62b9dff31c8aa99922d713"

    let workspaceRoot: URL
    let manifestURL: URL
    let reportFilename: String
    let reviewPacketFilename: String
    let freezeRequestFilename: String
    let modelURL: URL
    let helperURL: URL
    let backgroundLoad: String
    let expectedSourceBundleSHA256: String
    let expectedTestExecutableSHA256: String

    static func isRequested(_ environment: [String: String]) -> Bool {
        requiredEnvironmentKeys.contains { environment[$0] != nil }
    }

    static func load(_ environment: [String: String]) throws -> Self? {
        guard isRequested(environment) else { return nil }
        guard requiredEnvironmentKeys.allSatisfy({ !(environment[$0] ?? "").isEmpty }) else {
            throw TranslationQualificationError.invalidManifest(
                "translation qualification environment is incomplete"
            )
        }
        let workspace =
            environment["TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"]
            ?? FileManager.default.currentDirectoryPath
        let filenames = try privateFilenames(environment)
        let sourceHash = try requiredSHA(
            "TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256",
            environment
        )
        let executableHash = try requiredSHA(
            "TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256",
            environment
        )
        try validatePrivateFilenames(filenames)
        return try makeConfiguration(
            workspace: workspace,
            filenames: filenames,
            sourceHash: sourceHash,
            executableHash: executableHash,
            environment: environment
        )
    }

    var providerSettings: [String: String] {
        let value = providerConfiguration
        return [
            "contextSize": String(value.contextSize),
            "gpuLayerCount": String(value.gpuLayerCount),
            "maximumGlossaryTerms": String(value.maximumGlossaryTerms),
            "maximumOutputTokens": String(value.maximumOutputTokens),
            "modelFilename": value.modelFilename,
            "requestTimeoutSeconds": String(value.requestTimeout),
            "threadCount": String(value.threadCount),
            "qualificationGlossaryCatalogPolicy": HyMTQualificationGlossary.theologyPolicyID,
            "qualificationGlossaryCatalogSHA256": HyMTQualificationGlossary.catalogSHA256,
            "qualificationRunnerPolicy": "hymt-bilingual-sermon-v2",
            "buildConfiguration": "release",
            "translationContextEntries": "2", "discourseContextEntries": "2",
            "temperature": "0.7", "topP": "0.6", "topK": "20",
            "repetitionPenalty": "1.05", "seed": "42", "stream": "false",
        ]
    }

    var providerConfiguration: HyMT2Configuration {
        HyMT2Configuration()
    }

    private static func requiredURL(
        _ key: String,
        _ environment: [String: String]
    ) throws -> URL {
        guard let path = environment[key], !path.isEmpty else {
            throw TranslationQualificationError.invalidManifest("missing environment key \(key)")
        }
        return URL(fileURLWithPath: path)
    }

    private static func requiredValue(
        _ key: String,
        _ environment: [String: String]
    ) throws -> String {
        guard let value = environment[key], !value.isEmpty else {
            throw TranslationQualificationError.invalidManifest("missing environment key \(key)")
        }
        return value
    }

    private static func requiredSHA(
        _ key: String,
        _ environment: [String: String]
    ) throws -> String {
        let value = try requiredValue(key, environment)
        guard value.count == 64,
            value.allSatisfy({ $0.isHexDigit && !$0.isUppercase })
        else {
            throw TranslationQualificationError.invalidManifest("invalid environment hash \(key)")
        }
        return value
    }
}

extension HyMTQualificationConfiguration {
    fileprivate struct PrivateFilenames {
        let report: String
        let reviewPacket: String
        let freezeRequest: String
    }

    fileprivate static func privateFilenames(_ environment: [String: String]) throws -> PrivateFilenames {
        let report = try requiredValue("BILINGUAL_TRANSLATION_REPORT", environment)
        return PrivateFilenames(
            report: report,
            reviewPacket: environment["BILINGUAL_TRANSLATION_REVIEW_PACKET"]
                ?? String(report.dropLast(5)) + ".review-packet.json",
            freezeRequest: environment["BILINGUAL_TRANSLATION_FREEZE_REQUEST"]
                ?? String(report.dropLast(5)) + ".freeze-request.json"
        )
    }

    fileprivate static func validatePrivateFilenames(_ filenames: PrivateFilenames) throws {
        try TranslationQualificationReportWriter.validatePrivateFilename(filenames.report)
        try TranslationQualificationReportWriter.validatePrivateFilename(filenames.reviewPacket)
        try TranslationQualificationReportWriter.validatePrivateFilename(filenames.freezeRequest)
    }

    fileprivate static func makeConfiguration(
        workspace: String,
        filenames: PrivateFilenames,
        sourceHash: String,
        executableHash: String,
        environment: [String: String]
    ) throws -> Self {
        Self(
            workspaceRoot: URL(fileURLWithPath: workspace, isDirectory: true),
            manifestURL: try requiredURL("BILINGUAL_TRANSLATION_MANIFEST", environment),
            reportFilename: filenames.report,
            reviewPacketFilename: filenames.reviewPacket,
            freezeRequestFilename: filenames.freezeRequest,
            modelURL: try requiredURL("HYMT_MODEL_DIR", environment),
            helperURL: try requiredURL("HYMT_LLAMA_SERVER", environment),
            backgroundLoad: environment["TRANSLATION_QUALIFICATION_BACKGROUND_LOAD"]
                ?? "uncontrolled-user-session",
            expectedSourceBundleSHA256: sourceHash,
            expectedTestExecutableSHA256: executableHash
        )
    }
}
