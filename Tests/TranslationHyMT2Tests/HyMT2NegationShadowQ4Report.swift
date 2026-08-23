import Foundation

enum HyMT2NegationShadowQ4Status: String, Codable, Sendable {
    case failed
    case passed
}

struct HyMT2NegationShadowQ4Result: Codable, Equatable, Sendable {
    let fixtureID: String
    let encoding: String
    let occurrenceCount: Int
    let status: HyMT2NegationShadowQ4Status
    let failureCode: String?
    let latencyMilliseconds: Double
    let outputSHA256: String?
}

struct HyMT2NegationShadowQ4Report: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let seed: Int
    let temperature: Double
    let threadCount: Int
    let modelSHA256: String
    let helperSHA256: String
    let backgroundLoad: String
    let latencyControlled: Bool
    let results: [HyMT2NegationShadowQ4Result]

    init(
        environment: HyMT2NegationShadowQ4Environment,
        results: [HyMT2NegationShadowQ4Result]
    ) {
        schemaVersion = 1
        seed = HyMT2NegationShadowQ4Settings.seed
        temperature = HyMT2NegationShadowQ4Settings.temperature
        threadCount = HyMT2NegationShadowQ4Settings.threadCount
        modelSHA256 = environment.modelSHA256
        helperSHA256 = environment.helperSHA256
        backgroundLoad = "idle-sibling-q8-resident"
        latencyControlled = false
        self.results = results
    }
}

enum HyMT2NegationShadowQ4ReportError: Error, Equatable {
    case invalidFailureCode
    case invalidHash
    case invalidLatency
    case invalidResult
}

enum HyMT2NegationShadowQ4ReportWriter {
    static func write(
        _ report: HyMT2NegationShadowQ4Report,
        to url: URL
    ) throws {
        let data = try encoded(report)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    static func encoded(_ report: HyMT2NegationShadowQ4Report) throws -> Data {
        try validate(report)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(report)
    }

    private static func validate(_ report: HyMT2NegationShadowQ4Report) throws {
        guard isSHA256(report.modelSHA256), isSHA256(report.helperSHA256) else {
            throw HyMT2NegationShadowQ4ReportError.invalidHash
        }
        for result in report.results {
            guard result.latencyMilliseconds.isFinite, result.latencyMilliseconds >= 0 else {
                throw HyMT2NegationShadowQ4ReportError.invalidLatency
            }
            guard try hasConsistentOutcome(result), (0...3).contains(result.occurrenceCount),
                ["englishNot", "originalCue"].contains(result.encoding),
                isSafeFixtureID(result.fixtureID)
            else {
                throw HyMT2NegationShadowQ4ReportError.invalidResult
            }
            if let code = result.failureCode, !allowedFailureCodes.contains(code) {
                throw HyMT2NegationShadowQ4ReportError.invalidFailureCode
            }
        }
    }

    private static func hasConsistentOutcome(
        _ result: HyMT2NegationShadowQ4Result
    ) throws -> Bool {
        if let hash = result.outputSHA256, !isSHA256(hash) {
            throw HyMT2NegationShadowQ4ReportError.invalidHash
        }
        switch (result.status, result.failureCode) {
        case (.passed, nil):
            return result.outputSHA256 != nil
        case (.failed, .some("neg.shadow.transport")):
            return result.outputSHA256 == nil
        case (.failed, .some):
            return result.outputSHA256 != nil
        default:
            return false
        }
    }

    private static let allowedFailureCodes: Set<String> = {
        let parserCodes = HyMT2NegationShadowFailureCategory.allCases.map {
            "neg.shadow." + $0.rawValue
        }
        return Set(
            parserCodes + [
                "neg.shadow.runtime.output", "neg.shadow.semantic.anchor",
                "neg.shadow.semantic.occurrence", "neg.shadow.transport",
            ])
    }()

    private static func isSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func isSafeFixtureID(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64
            && value.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "." }
    }
}
