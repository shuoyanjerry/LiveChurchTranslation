import Foundation

enum QualificationWAVParser {
    static func parse(_ data: Data) throws -> QualificationWAVDescriptor {
        guard data.count >= 12,
            data.matches([82, 73, 70, 70], at: 0),
            data.matches([87, 65, 86, 69], at: 8)
        else {
            throw ASRQualificationError.unsupportedWAV("expected RIFF/WAVE header")
        }
        let declaredSize = try exactInt(data.littleUInt32(at: 4)) + 8
        guard declaredSize == data.count else {
            throw ASRQualificationError.unsupportedWAV("RIFF size does not match file size")
        }
        let chunks = try scanChunks(in: data, limit: declaredSize)
        guard let formatRange = chunks.format, let audioRange = chunks.audio else {
            throw ASRQualificationError.unsupportedWAV("missing fmt or data chunk")
        }
        let format = try parseFormat(in: data, range: formatRange)
        guard audioRange.count > 0, audioRange.count.isMultiple(of: format.encoding.byteWidth) else {
            throw ASRQualificationError.unsupportedWAV("invalid data chunk length")
        }
        return QualificationWAVDescriptor(
            sampleRate: format.sampleRate,
            totalSamples: audioRange.count / format.encoding.byteWidth,
            dataOffset: audioRange.lowerBound,
            encoding: format.encoding
        )
    }

    private static func scanChunks(in data: Data, limit: Int) throws -> WAVChunks {
        var result = WAVChunks()
        var offset = 12
        while offset < limit {
            guard offset <= limit - 8 else {
                throw ASRQualificationError.unsupportedWAV("truncated chunk header")
            }
            let size = try exactInt(data.littleUInt32(at: offset + 4))
            let start = offset + 8
            let (end, overflow) = start.addingReportingOverflow(size)
            guard !overflow, end <= limit else {
                throw ASRQualificationError.unsupportedWAV("chunk exceeds RIFF bounds")
            }
            if data.matches([102, 109, 116, 32], at: offset) {
                guard result.format == nil else { try rejectDuplicate("fmt") }
                result.format = start..<end
            } else if data.matches([100, 97, 116, 97], at: offset) {
                guard result.audio == nil else { try rejectDuplicate("data") }
                result.audio = start..<end
            }
            let padded = end + size % 2
            guard padded <= limit else {
                throw ASRQualificationError.unsupportedWAV("missing chunk padding byte")
            }
            offset = padded
        }
        return result
    }

    private static func parseFormat(in data: Data, range: Range<Int>) throws -> WAVFormat {
        guard range.count >= 16 else {
            throw ASRQualificationError.unsupportedWAV("fmt chunk is too short")
        }
        let channels = Int(data.littleUInt16(at: range.lowerBound + 2))
        let sampleRate = try exactInt(data.littleUInt32(at: range.lowerBound + 4))
        let byteRate = try exactInt(data.littleUInt32(at: range.lowerBound + 8))
        let blockAlign = Int(data.littleUInt16(at: range.lowerBound + 12))
        let bitsPerSample = Int(data.littleUInt16(at: range.lowerBound + 14))
        var formatCode = data.littleUInt16(at: range.lowerBound)
        if formatCode == 0xFFFE {
            formatCode = try extensibleFormatCode(in: data, range: range, bits: bitsPerSample)
        }
        let encoding = try encoding(code: formatCode, bits: bitsPerSample)
        guard channels == 1, blockAlign == encoding.byteWidth,
            byteRate == sampleRate * encoding.byteWidth
        else {
            throw ASRQualificationError.unsupportedWAV("only mono uncompressed PCM is supported")
        }
        return WAVFormat(sampleRate: sampleRate, encoding: encoding)
    }

    private static func extensibleFormatCode(
        in data: Data,
        range: Range<Int>,
        bits: Int
    ) throws -> UInt16 {
        let suffix: [UInt8] = [0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113]
        guard range.count >= 40,
            data.littleUInt16(at: range.lowerBound + 16) >= 22,
            Int(data.littleUInt16(at: range.lowerBound + 18)) == bits,
            data.matches(suffix, at: range.lowerBound + 28)
        else {
            throw ASRQualificationError.unsupportedWAV("invalid WAVE_FORMAT_EXTENSIBLE fmt")
        }
        let code = data.littleUInt32(at: range.lowerBound + 24)
        guard code <= UInt16.max else {
            throw ASRQualificationError.unsupportedWAV("unsupported extensible subformat")
        }
        return UInt16(code)
    }

    private static func encoding(
        code: UInt16,
        bits: Int
    ) throws -> QualificationWAVEncoding {
        switch (code, bits) {
        case (1, 16): .pcm16
        case (3, 32): .float32
        default: throw ASRQualificationError.unsupportedWAV("unsupported PCM encoding")
        }
    }

    private static func exactInt(_ value: UInt32) throws -> Int {
        guard let converted = Int(exactly: value) else {
            throw ASRQualificationError.unsupportedWAV("WAV integer exceeds platform range")
        }
        return converted
    }

    private static func rejectDuplicate(_ name: String) throws -> Never {
        throw ASRQualificationError.unsupportedWAV("duplicate \(name) chunk")
    }
}

private struct WAVChunks {
    var format: Range<Int>?
    var audio: Range<Int>?
}

private struct WAVFormat {
    let sampleRate: Int
    let encoding: QualificationWAVEncoding
}

extension Data {
    func littleUInt16(at index: Int) -> UInt16 {
        UInt16(self[index]) | UInt16(self[index + 1]) << 8
    }

    func littleUInt32(at index: Int) -> UInt32 {
        UInt32(littleUInt16(at: index)) | UInt32(littleUInt16(at: index + 2)) << 16
    }

    func matches(_ bytes: [UInt8], at index: Int) -> Bool {
        guard index >= 0, index <= count - bytes.count else { return false }
        return bytes.indices.allSatisfy { self[index + $0] == bytes[$0] }
    }
}
