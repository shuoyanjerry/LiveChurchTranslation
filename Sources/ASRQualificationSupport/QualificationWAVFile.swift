import Foundation

struct QualificationWAVFile {
    let rawSHA256: String
    let sampleRate: Int
    let totalSamples: Int

    private let data: Data
    private let dataOffset: Int
    private let encoding: QualificationWAVEncoding

    init(contentsOf url: URL) throws {
        let loadedData: Data
        do {
            loadedData = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ASRQualificationError.audioReadFailed(url.path)
        }
        let descriptor = try QualificationWAVParser.parse(loadedData)
        data = loadedData
        rawSHA256 = QualificationSHA256.data(loadedData)
        sampleRate = descriptor.sampleRate
        totalSamples = descriptor.totalSamples
        dataOffset = descriptor.dataOffset
        encoding = descriptor.encoding
    }

    func samples(start: Int, count: Int) throws -> [Float] {
        guard start >= 0, count >= 0, start <= totalSamples - count else {
            throw ASRQualificationError.unsupportedWAV("sample read exceeds data chunk")
        }
        let stride = encoding.byteWidth
        let (relativeOffset, multiplicationOverflow) = start.multipliedReportingOverflow(by: stride)
        let (byteOffset, additionOverflow) = dataOffset.addingReportingOverflow(relativeOffset)
        guard !multiplicationOverflow, !additionOverflow else {
            throw ASRQualificationError.unsupportedWAV("sample byte offset overflow")
        }
        return try decodeSamples(
            at: byteOffset,
            sourceStart: start,
            count: count,
            encoding: encoding
        )
    }

    private func decodeSamples(
        at offset: Int,
        sourceStart: Int,
        count: Int,
        encoding: QualificationWAVEncoding
    ) throws -> [Float] {
        var result: [Float] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let position = offset + index * encoding.byteWidth
            switch encoding {
            case .float32:
                let sample = Float(bitPattern: data.littleUInt32(at: position))
                guard sample.isFinite else {
                    throw QualificationWAVReadError.nonFiniteSample(sourceStart + index)
                }
                result.append(sample)
            case .pcm16:
                let raw = data.littleUInt16(at: position)
                result.append(Float(Int16(bitPattern: raw)) / 32_768)
            }
        }
        guard result.count == count else {
            throw ASRQualificationError.unsupportedWAV("short PCM read")
        }
        return result
    }
}

enum QualificationWAVReadError: Error {
    case nonFiniteSample(Int)
}

enum QualificationWAVEncoding {
    case pcm16
    case float32

    var byteWidth: Int {
        switch self {
        case .pcm16: 2
        case .float32: 4
        }
    }
}

struct QualificationWAVDescriptor {
    let sampleRate: Int
    let totalSamples: Int
    let dataOffset: Int
    let encoding: QualificationWAVEncoding
}
