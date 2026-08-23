import Foundation

enum JSONShape {
    static func object(_ value: Any, path: String) throws -> [String: Any] {
        guard let object = value as? [String: Any] else {
            throw TranslationQualificationError.invalidJSON("\(path) must be an object")
        }
        return object
    }

    static func array(_ value: Any, path: String) throws -> [Any] {
        guard let array = value as? [Any] else {
            throw TranslationQualificationError.invalidJSON("\(path) must be an array")
        }
        return array
    }

    static func exactKeys(
        _ expected: Set<String>,
        in object: [String: Any],
        path: String
    ) throws {
        let actual = Set(object.keys)
        guard actual == expected else {
            let missing = expected.subtracting(actual).sorted().joined(separator: ",")
            let extra = actual.subtracting(expected).sorted().joined(separator: ",")
            throw TranslationQualificationError.invalidJSON(
                "\(path) keys differ; missing=[\(missing)] extra=[\(extra)]"
            )
        }
    }

    static func objects(_ value: Any, path: String) throws -> [[String: Any]] {
        try array(value, path: path).enumerated().map { index, item in
            try object(item, path: "\(path)[\(index)]")
        }
    }
}
