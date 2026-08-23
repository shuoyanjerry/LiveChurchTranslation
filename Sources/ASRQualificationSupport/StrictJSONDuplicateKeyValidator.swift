import Foundation

/// Detects duplicate object names before Foundation can collapse them last-value-wins.
enum StrictJSONDuplicateKeyValidator {
    static func validate(_ data: Data) throws {
        var parser = StrictJSONParser(bytes: Array(data))
        try parser.parseDocument()
    }
}

private struct StrictJSONParser {
    let bytes: [UInt8]
    var index = 0

    mutating func parseDocument() throws {
        skipWhitespace()
        try parseValue(path: "$")
        skipWhitespace()
        guard index == bytes.count else { throw ASRQualificationError.malformedManifest }
    }

    private mutating func parseValue(path: String) throws {
        guard let byte = current else { throw ASRQualificationError.malformedManifest }
        switch byte {
        case 0x7B: try parseObject(path: path)
        case 0x5B: try parseArray(path: path)
        case 0x22: _ = try parseString()
        case 0x74: try consumeLiteral("true")
        case 0x66: try consumeLiteral("false")
        case 0x6E: try consumeLiteral("null")
        default: try consumeNumberToken()
        }
    }

    private mutating func parseObject(path: String) throws {
        index += 1
        skipWhitespace()
        if consume(0x7D) { return }
        var fields = Set<String>()
        while true {
            let field = try parseString()
            guard fields.insert(field).inserted else {
                throw ASRQualificationError.duplicateJSONField(path: path, field: field)
            }
            skipWhitespace()
            try require(0x3A)
            skipWhitespace()
            try parseValue(path: childPath(path, field: field))
            skipWhitespace()
            if consume(0x7D) { return }
            try require(0x2C)
            skipWhitespace()
        }
    }

    private mutating func parseArray(path: String) throws {
        index += 1
        skipWhitespace()
        if consume(0x5D) { return }
        var element = 0
        while true {
            try parseValue(path: "\(path)[\(element)]")
            element += 1
            skipWhitespace()
            if consume(0x5D) { return }
            try require(0x2C)
            skipWhitespace()
        }
    }

    private mutating func parseString() throws -> String {
        guard current == 0x22 else { throw ASRQualificationError.malformedManifest }
        let start = index
        index += 1
        while let byte = current {
            if byte == 0x22 {
                index += 1
                return try decodeString(from: start, through: index)
            }
            guard byte >= 0x20 else { throw ASRQualificationError.malformedManifest }
            index += byte == 0x5C ? 2 : 1
            guard index <= bytes.count else { throw ASRQualificationError.malformedManifest }
        }
        throw ASRQualificationError.malformedManifest
    }

    private func decodeString(from start: Int, through end: Int) throws -> String {
        do {
            return try JSONDecoder().decode(String.self, from: Data(bytes[start..<end]))
        } catch {
            throw ASRQualificationError.malformedManifest
        }
    }

    private mutating func consumeLiteral(_ literal: StaticString) throws {
        let expected = Array("\(literal)".utf8)
        guard bytes[index...].starts(with: expected) else {
            throw ASRQualificationError.malformedManifest
        }
        index += expected.count
    }

    private mutating func consumeNumberToken() throws {
        let start = index
        while let byte = current, !Self.delimiters.contains(byte) { index += 1 }
        guard index > start else { throw ASRQualificationError.malformedManifest }
    }

    private mutating func require(_ byte: UInt8) throws {
        guard consume(byte) else { throw ASRQualificationError.malformedManifest }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard current == byte else { return false }
        index += 1
        return true
    }

    private mutating func skipWhitespace() {
        while let byte = current, Self.whitespace.contains(byte) { index += 1 }
    }

    private func childPath(_ path: String, field: String) -> String {
        "\(path).\(field)"
    }

    private var current: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private static let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
    private static let delimiters = whitespace.union([0x2C, 0x5D, 0x7D])
}
