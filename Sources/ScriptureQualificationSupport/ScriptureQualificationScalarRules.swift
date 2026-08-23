import Foundation

enum ScriptureQualificationScalarRules {
    static func requireText(_ value: String, label: String, maximum: Int = 512) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, value.count <= maximum else {
            throw ScriptureQualificationError.invalidManifest("invalid \(label)")
        }
    }

    static func requireID(_ value: String, label: String) throws {
        try requireText(value, label: label, maximum: 128)
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        guard value.unicodeScalars.allSatisfy(allowed.contains) else {
            throw ScriptureQualificationError.invalidManifest("invalid \(label)")
        }
    }

    static func requireHash(_ value: String, label: String) throws {
        let hexadecimal = CharacterSet(charactersIn: "0123456789abcdef")
        guard value.count == 64, value.unicodeScalars.allSatisfy(hexadecimal.contains) else {
            throw ScriptureQualificationError.invalidManifest("invalid SHA-256 at \(label)")
        }
    }

    static func requireRelativePath(_ value: String, label: String) throws {
        try requireText(value, label: label, maximum: 1_024)
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        guard
            !value.hasPrefix("/"),
            !value.contains("\\"),
            components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw ScriptureQualificationError.unsafePath("invalid relative path at \(label)")
        }
    }

    static func date(_ value: String, label: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        let basic = formatter.date(from: value)
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = basic ?? formatter.date(from: value) else {
            throw ScriptureQualificationError.invalidManifest("invalid ISO-8601 date at \(label)")
        }
        return date
    }
}
