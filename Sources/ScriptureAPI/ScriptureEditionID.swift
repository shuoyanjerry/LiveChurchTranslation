public struct ScriptureEditionID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let englishStandardVersion2025 = Self(rawValue: "esv-2025")
    public static let newPunctuationCUVShenSimplified1988 = Self(
        rawValue: "cunpss-shen-1988-zh-Hans"
    )
}
