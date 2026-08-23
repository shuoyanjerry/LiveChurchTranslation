import Foundation

extension TranslationManifestValidator {
    static func provenanceHashes(_ value: TranslationQualificationProvenance) -> [String] {
        [value.builderSHA256, value.configSHA256, value.candidateConfigSHA256, value.supportSHA256]
    }

    static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    static func isISO8601(_ value: String) -> Bool {
        if ISO8601DateFormatter().date(from: value) != nil { return true }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) != nil
    }

    static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidManifest(message) }
    }
}
