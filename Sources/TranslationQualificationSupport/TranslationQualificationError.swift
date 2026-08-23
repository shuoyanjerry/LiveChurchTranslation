import Foundation

public enum TranslationQualificationError: Error, Equatable, Sendable {
    case invalidJSON(String)
    case invalidManifest(String)
    case hashMismatch(label: String, expected: String, actual: String)
    case missingFile(String)
    case unsafePath(String)
    case invalidReport(String)
    case writeFailed(String)
}
