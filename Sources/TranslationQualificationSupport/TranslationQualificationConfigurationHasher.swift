import Foundation

public enum TranslationConfigurationHasher {
    public static func hash(settings: [String: String]) throws -> String {
        guard !settings.isEmpty,
            settings.allSatisfy({ !$0.key.isEmpty && !$0.value.isEmpty }),
            settings["buildConfiguration"] == "release",
            settings["qualificationGlossaryCatalogPolicy"]?.isEmpty == false,
            isSHA(settings["qualificationGlossaryCatalogSHA256"]),
            positiveInteger(settings["translationContextEntries"]),
            positiveInteger(settings["discourseContextEntries"])
        else {
            throw TranslationQualificationError.invalidReport(
                "translation qualification configuration is empty"
            )
        }
        let entries = settings.map(ConfigurationEntry.init).sorted { $0.key < $1.key }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return TranslationQualificationSHA256.hash(data: try encoder.encode(entries))
    }

    private static func isSHA(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func positiveInteger(_ value: String?) -> Bool {
        guard let value, let number = Int(value) else { return false }
        return number > 0
    }
}

private struct ConfigurationEntry: Encodable {
    let key: String
    let value: String

    init(_ value: (key: String, value: String)) {
        key = value.key
        self.value = value.value
    }
}
