import Foundation

enum CandidatePausePrivacyValidator {
    static func validate(
        encoded data: Data,
        forbiddenValues: [String]
    ) throws {
        let object = try JSONSerialization.jsonObject(with: data)
        let forbiddenKeys = Set(["fileName", "path", "transcript", "text", "sourceText"])
        guard !containsForbiddenKey(object, forbiddenKeys: forbiddenKeys) else {
            throw CandidatePauseBenchmarkError.invalidTrace("private field encoded")
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw CandidatePauseBenchmarkError.invalidTrace("report encoding is not UTF-8")
        }
        guard !forbiddenValues.filter({ !$0.isEmpty }).contains(where: string.contains) else {
            throw CandidatePauseBenchmarkError.invalidTrace("private value encoded")
        }
    }

    private static func containsForbiddenKey(
        _ value: Any,
        forbiddenKeys: Set<String>
    ) -> Bool {
        if let dictionary = value as? [String: Any] {
            if !forbiddenKeys.isDisjoint(with: dictionary.keys) { return true }
            return dictionary.values.contains { containsForbiddenKey($0, forbiddenKeys: forbiddenKeys) }
        }
        if let array = value as? [Any] {
            return array.contains { containsForbiddenKey($0, forbiddenKeys: forbiddenKeys) }
        }
        return false
    }
}
