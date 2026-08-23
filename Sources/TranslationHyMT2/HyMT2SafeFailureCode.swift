import CryptoKit
import Foundation
import TranslationAPI

public enum HyMT2SafeFailureCode {
    public static func make(_ error: any Error) -> String {
        if let error = error as? HyMT2Error { return hyMT(error) }
        if let error = error as? TranslationProviderError { return provider(error) }
        if error is CancellationError { return "hymt.cancelled" }
        let typeName = String(reflecting: type(of: error))
        let digest = SHA256.hash(data: Data(typeName.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return "hymt.unclassified.\(digest.prefix(12))"
    }

    private static func hyMT(_ error: HyMT2Error) -> String {
        switch error {
        case .helperUnavailable, .modelUnavailable, .launchFailed, .startupTimedOut:
            startup(error)
        case .serverTerminated: "hymt.server-terminated"
        case .modelNotLoaded: "hymt.model-not-loaded"
        case .transportFailure: "hymt.transport-failure"
        case .malformedResponse: "hymt.malformed-response"
        case .invalidInput: "hymt.input-rejected"
        case .invalidOutput(let reasons): strictValidation(reasons)
        }
    }

    private static func startup(_ error: HyMT2Error) -> String {
        switch error {
        case .helperUnavailable: "hymt.helper-unavailable"
        case .modelUnavailable: "hymt.model-unavailable"
        case .launchFailed: "hymt.launch-failed"
        case .startupTimedOut: "hymt.startup-timeout"
        default: "hymt.startup-unclassified"
        }
    }

    private static func strictValidation(_ reasons: [String]) -> String {
        var categories = Set(reasons.map(StrictValidationCategory.classify))
        if categories.isEmpty { categories.insert(.other) }
        let suffix = StrictValidationCategory.allCases
            .filter(categories.contains)
            .map(\.code)
            .joined(separator: ".")
        return "hymt.strict.\(suffix)"
    }

    private static func provider(_ error: TranslationProviderError) -> String {
        switch error {
        case .languageModelUnavailable: "translation.language-model-unavailable"
        case .runtimeNotAttached: "translation.runtime-not-attached"
        case .emptySource: "translation.empty-source"
        case .invalidOutput: "translation.invalid-output"
        case .translationFailed: "translation.failed"
        }
    }
}

private enum StrictValidationCategory: String, CaseIterable {
    case empty
    case length
    case meta
    case promptControl = "prompt-control"
    case sourceScript = "source-script"
    case missingTerm = "missing-term"
    case missingNumber = "missing-number"
    case negation
    case scripture
    case pronounProtocol = "pronoun-protocol"
    case other

    var code: String {
        switch self {
        case .empty: "empty"
        case .length: "len"
        case .meta: "meta"
        case .promptControl: "ctl"
        case .sourceScript: "zh"
        case .missingTerm: "term"
        case .missingNumber: "num"
        case .negation: "neg"
        case .scripture: "verse"
        case .pronounProtocol: "pron"
        case .other: "other"
        }
    }

    static func classify(_ reason: String) -> Self {
        if let exact = exactReasons[reason] { return exact }
        if knownPrefixes.contains(where: reason.hasPrefix) { return .pronounProtocol }
        if reason.hasPrefix("missing required term: ") { return .missingTerm }
        if reason.hasPrefix("missing number: ") { return .missingNumber }
        return .other
    }

    private static let exactReasons: [String: Self] = [
        "empty output": .empty,
        "implausible output length": .length,
        "model commentary or instruction text": .meta,
        "prompt-control delimiter remains in output": .promptControl,
        "Chinese source script remains in English output": .sourceScript,
        "output script does not match the target language": .sourceScript,
        "source negation was not preserved": .negation,
        "Scripture reference was not preserved": .scripture,
        "malformed or incomplete pronoun marker": .pronounProtocol,
    ]

    private static let knownPrefixes = [
        "pronoun source range ",
        "duplicate pronoun source range:",
        "pronoun source ranges overlap ",
        "pronoun occurrence count exceeds marker capacity: ",
        "reserved pronoun marker prefix appears in ",
        "pronoun marker ",
        "duplicate pronoun marker: ",
        "unknown pronoun marker: ",
    ]
}
