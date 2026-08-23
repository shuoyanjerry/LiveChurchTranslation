import Foundation

public enum ScriptureQualificationError: Error, Equatable, Sendable {
    case malformedManifest
    case duplicateJSONField(path: String, field: String)
    case unknownJSONFields(path: String, fields: [String])
    case invalidManifest(String)
    case unsafePath(String)
    case missingFile(String)
    case invalidFile(String)
    case fileTooLarge(String)
    case hashMismatch(label: String, expected: String, actual: String)
}

extension ScriptureQualificationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .malformedManifest:
            "Manifest is not valid strict JSON."
        case .duplicateJSONField(let path, let field):
            "Duplicate JSON field at \(path): \(field)"
        case .unknownJSONFields(let path, let fields):
            "Unknown JSON fields at \(path): \(fields.joined(separator: ", "))"
        case .invalidManifest(let reason):
            "Manifest rejected: \(reason)"
        case .unsafePath(let reason):
            "Unsafe private-corpus path: \(reason)"
        case .missingFile(let label):
            "Missing private-corpus file: \(label)"
        case .invalidFile(let label):
            "Invalid private-corpus file: \(label)"
        case .fileTooLarge(let label):
            "Private-corpus file exceeds its limit: \(label)"
        case .hashMismatch(let label, let expected, let actual):
            "SHA-256 mismatch for \(label); expected \(expected), got \(actual)."
        }
    }
}
