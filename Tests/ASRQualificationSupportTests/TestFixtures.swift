import ASRQualificationSupport
import CryptoKit
import Foundation

let testHash = String(repeating: "a", count: 64)

func testProvenance() -> ASRQualificationProvenanceV2 {
    ASRQualificationProvenanceV2(
        sourceVADReportSHA256: String(repeating: "b", count: 64),
        sourceVADStrategy: "webrtc-stable-v1",
        sourceVADConfigurationSHA256: String(repeating: "c", count: 64),
        sourceReferenceManifestSHA256: String(repeating: "d", count: 64),
        sourceCorpusManifestSHA256: String(repeating: "e", count: 64),
        generatorRevision: "qualification-manifest-v2"
    )
}

func testSegment(
    sequence: Int = 1,
    start: Int = 0,
    end: Int = 2,
    valid: Int = 2,
    padding: Int = 0,
    reason: String = "maximum-duration",
    pcmSHA256: String = testHash
) -> ASRQualificationSegmentV2 {
    ASRQualificationSegmentV2(
        sequence: sequence,
        startSample: start,
        endSample: end,
        validSampleCount: valid,
        syntheticPaddingSamples: padding,
        endReason: reason,
        pcmSHA256: pcmSHA256
    )
}

func testClip(
    id: String = "clip",
    audioSHA256: String = testHash,
    sampleRate: Int = 16_000,
    totalSamples: Int = 4,
    referenceSHA256: String = testHash,
    allowsHypothesisEdgeInsertions: Bool = true,
    segments: [ASRQualificationSegmentV2] = [testSegment()]
) -> ASRQualificationClipV2 {
    ASRQualificationClipV2(
        id: id,
        audioSHA256: audioSHA256,
        sampleRate: sampleRate,
        totalSamples: totalSamples,
        referenceSHA256: referenceSHA256,
        allowsHypothesisEdgeInsertions: allowsHypothesisEdgeInsertions,
        segments: segments
    )
}

func testManifest(
    schemaVersion: Int = 2,
    corpusID: String = "public-domain-mandarin-scripture-v1",
    provenance: ASRQualificationProvenanceV2 = testProvenance(),
    clips: [ASRQualificationClipV2] = [testClip()]
) -> ASRQualificationManifestV2 {
    ASRQualificationManifestV2(
        schemaVersion: schemaVersion,
        corpusID: corpusID,
        provenance: provenance,
        clips: clips
    )
}

func encoded(_ manifest: ASRQualificationManifestV2) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(manifest)
}

func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

func pcmSHA256(_ samples: [Float]) -> String {
    var bytes = Data()
    for sample in samples {
        var bits = sample.bitPattern.littleEndian
        withUnsafeBytes(of: &bits) { bytes.append(contentsOf: $0) }
    }
    return sha256(bytes)
}

func floatWAV(
    _ samples: [Float],
    sampleRate: Int = 16_000,
    channels: UInt16 = 1,
    extensible: Bool = false
) -> Data {
    var audio = Data()
    for sample in samples {
        audio.appendLittleEndian(sample.bitPattern)
    }
    let format = floatFormat(
        sampleRate: sampleRate,
        channels: channels,
        extensible: extensible
    )
    return riffWAV(format: format, audio: audio)
}

func pcm16WAV(_ samples: [Int16], sampleRate: Int = 16_000) -> Data {
    var audio = Data()
    for sample in samples {
        audio.appendLittleEndian(UInt16(bitPattern: sample))
    }
    var format = Data()
    format.appendLittleEndian(UInt16(1))
    format.appendLittleEndian(UInt16(1))
    format.appendLittleEndian(UInt32(sampleRate))
    format.appendLittleEndian(UInt32(sampleRate * 2))
    format.appendLittleEndian(UInt16(2))
    format.appendLittleEndian(UInt16(16))
    return riffWAV(format: format, audio: audio)
}

func temporaryWAV(_ data: Data) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("wav")
    try data.write(to: url)
    return url
}

private func floatFormat(sampleRate: Int, channels: UInt16, extensible: Bool) -> Data {
    let width = Int(channels) * 4
    var data = Data()
    data.appendLittleEndian(UInt16(extensible ? 0xFFFE : 3))
    data.appendLittleEndian(channels)
    data.appendLittleEndian(UInt32(sampleRate))
    data.appendLittleEndian(UInt32(sampleRate * width))
    data.appendLittleEndian(UInt16(width))
    data.appendLittleEndian(UInt16(32))
    guard extensible else { return data }
    data.appendLittleEndian(UInt16(22))
    data.appendLittleEndian(UInt16(32))
    data.appendLittleEndian(UInt32(4))
    data.append(contentsOf: [3, 0, 0, 0, 0, 0, 16, 0, 128, 0, 0, 170, 0, 56, 155, 113])
    return data
}

private func riffWAV(format: Data, audio: Data) -> Data {
    var body = Data("WAVE".utf8)
    body.appendChunk(id: "fmt ", payload: format)
    body.appendChunk(id: "data", payload: audio)
    var result = Data("RIFF".utf8)
    result.appendLittleEndian(UInt32(body.count))
    result.append(body)
    return result
}

extension Data {
    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }

    mutating func appendChunk(id: String, payload: Data) {
        append(Data(id.utf8))
        appendLittleEndian(UInt32(payload.count))
        append(payload)
        if !payload.count.isMultiple(of: 2) { append(0) }
    }
}
