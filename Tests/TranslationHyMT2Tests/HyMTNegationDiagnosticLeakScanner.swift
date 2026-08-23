import Foundation
import TranslationQualificationSupport

enum HyMTNegationDiagnosticLeakScanner {
    static func validate(
        _ object: Any,
        sensitiveTexts: [String]
    ) throws {
        var strings: [String] = []
        try scan(object, strings: &strings)
        let sensitive = sensitiveTexts.map(trimmed).filter { !$0.isEmpty }
        for value in strings {
            let leaks = sensitive.contains { secret in
                value == secret || (isHighSignal(secret) && value.contains(secret))
            }
            try require(!leaks, "diagnostic report contains protected text")
        }
    }

    private static func scan(_ value: Any, strings: inout [String]) throws {
        if let object = value as? [String: Any] {
            for (key, child) in object {
                try require(allowedKeys.contains(key), "diagnostic report has a forbidden field")
                strings.append(key)
                try scan(child, strings: &strings)
            }
        } else if let array = value as? [Any] {
            for child in array { try scan(child, strings: &strings) }
        } else if let string = value as? String {
            strings.append(string)
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isHighSignal(_ value: String) -> Bool {
        value.count >= 8 || value.unicodeScalars.contains(where: { $0.properties.isIdeographic })
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }

    private static let allowedKeys = Set([
        "schemaVersion", "generatedAt", "manifestSHA256", "classifiedReportSHA256",
        "modelSHA256", "entries", "segmentID", "sourceID", "sequence",
        "classifiedFailureCode", "sourceCueClasses", "referenceCueClass", "attemptCount",
        "totalLatencySeconds", "terminalFailureCode", "attempts", "ordinal", "phase",
        "completionOutcome", "targetCueClass", "validationIssueCodes", "latencySeconds",
        "outputAvailable", "outputSHA256",
    ])
}
