import Foundation

struct SpokenAudioFixtureCase: Sendable {
    let format: AudioFixtureFormat
    let language: FixtureLanguage

    static let required: [Self] = [
        .init(format: .wav, language: .mandarin),
        .init(format: .aiff, language: .english),
        .init(format: .aifc, language: .mandarin),
        .init(format: .caf, language: .english),
        .init(format: .aac, language: .mandarin),
        .init(format: .m4a, language: .english),
    ]

    static let mp3 = Self(format: .mp3, language: .english)
}

enum FixtureLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case mandarin = "zh-Hans"

    var voice: String {
        switch self {
        case .english: "Samantha"
        case .mandarin: "Tingting"
        }
    }

    var phrase: String {
        switch self {
        case .english: "Grace and peace."
        case .mandarin: "愿你平安。"
        }
    }
}

enum AudioFixtureFormat: String, CaseIterable, Sendable {
    case wav
    case aiff
    case aifc
    case caf
    case aac
    case m4a
    case mp3

    var fileExtension: String { rawValue }

    var afconvertArguments: [String] {
        switch self {
        case .wav: ["-f", "WAVE", "-d", "LEI16"]
        case .aiff: ["-f", "AIFF", "-d", "BEI16"]
        case .aifc: ["-f", "AIFC", "-d", "ima4"]
        case .caf: ["-f", "caff", "-d", "LEI16"]
        case .aac: ["-f", "adts", "-d", "aac", "-b", "64000"]
        case .m4a: ["-f", "m4af", "-d", "aac", "-b", "64000"]
        case .mp3: ["-f", "MPG3", "-d", ".mp3", "-b", "64000"]
        }
    }

    func validateSignature(at url: URL) throws {
        let prefix = try Data(contentsOf: url, options: .mappedIfSafe).prefix(12)
        let ascii = String(bytes: prefix, encoding: .isoLatin1) ?? ""
        let valid =
            switch self {
            case .wav: ascii.hasPrefix("RIFF") && ascii.dropFirst(8).hasPrefix("WAVE")
            case .aiff: ascii.hasPrefix("FORM") && ascii.dropFirst(8).hasPrefix("AIFF")
            case .aifc: ascii.hasPrefix("FORM") && ascii.dropFirst(8).hasPrefix("AIFC")
            case .caf: ascii.hasPrefix("caff")
            case .aac: prefix.count >= 2 && prefix[0] == 0xFF && prefix[1] & 0xF6 == 0xF0
            case .m4a: ascii.dropFirst(4).hasPrefix("ftyp")
            case .mp3:
                ascii.hasPrefix("ID3")
                    || (prefix.count >= 2 && prefix[0] == 0xFF && prefix[1] & 0xE0 == 0xE0)
            }
        guard valid else { throw FixtureError.invalidSignature(rawValue) }
    }
}
