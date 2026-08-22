import Foundation

enum PCM16WaveReader {
    static func read(_ location: URL) throws -> SemanticWaveFixture {
        let data = try Data(contentsOf: location)
        guard
            data.count >= 12,
            ascii(data, at: 0) == "RIFF",
            ascii(data, at: 8) == "WAVE"
        else { throw WaveFixtureError.invalidContainer }
        var offset = 12
        var format: WaveFormat?
        var sampleData: Data?
        while offset + 8 <= data.count {
            let identifier = ascii(data, at: offset)
            let size = Int(littleUInt32(data, at: offset + 4))
            let payloadStart = offset + 8
            guard size >= 0, payloadStart + size <= data.count else {
                throw WaveFixtureError.invalidContainer
            }
            if identifier == "fmt " {
                format = try parseFormat(data, at: payloadStart, size: size)
            } else if identifier == "data" {
                sampleData = data.subdata(in: payloadStart..<(payloadStart + size))
            }
            offset = payloadStart + size + (size % 2)
        }
        guard let format, let sampleData, sampleData.count.isMultiple(of: 2) else {
            throw WaveFixtureError.missingChunk
        }
        var samples: [Float] = []
        samples.reserveCapacity(sampleData.count / 2)
        for index in stride(from: 0, to: sampleData.count, by: 2) {
            let bits = littleUInt16(sampleData, at: index)
            samples.append(Float(Int16(bitPattern: bits)) / 32_768)
        }
        return SemanticWaveFixture(samples: samples, sampleRate: format.sampleRate)
    }

    private static func parseFormat(_ data: Data, at offset: Int, size: Int) throws -> WaveFormat {
        guard
            size >= 16,
            littleUInt16(data, at: offset) == 1,
            littleUInt16(data, at: offset + 2) == 1,
            littleUInt16(data, at: offset + 14) == 16
        else { throw WaveFixtureError.unsupportedFormat }
        return WaveFormat(sampleRate: Int(littleUInt32(data, at: offset + 4)))
    }

    private static func ascii(_ data: Data, at offset: Int) -> String {
        String(bytes: data[offset..<(offset + 4)], encoding: .ascii) ?? ""
    }

    private static func littleUInt16(_ data: Data, at offset: Int) -> UInt16 {
        UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func littleUInt32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(littleUInt16(data, at: offset))
            | (UInt32(littleUInt16(data, at: offset + 2)) << 16)
    }
}

struct SemanticWaveFixture {
    let samples: [Float]
    let sampleRate: Int
}

private struct WaveFormat {
    let sampleRate: Int
}

private enum WaveFixtureError: Error {
    case invalidContainer
    case missingChunk
    case unsupportedFormat
}
