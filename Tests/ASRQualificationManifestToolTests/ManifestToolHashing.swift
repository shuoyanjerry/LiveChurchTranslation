import CryptoKit
import Foundation

enum ManifestToolHashing {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func referenceText(_ text: String) -> String {
        sha256(Data(text.utf8))
    }

    static func configuration(_ configuration: VADConfiguration) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return sha256(try encoder.encode(configuration))
    }
}

struct ManifestToolDocuments {
    let vadData: Data
    let corpusData: Data
    let referenceData: Data
    let vad: VADReport
    let corpus: CorpusManifest
    let reference: ReferenceManifest

    init(vadData: Data, corpusData: Data, referenceData: Data) throws {
        self.vadData = vadData
        self.corpusData = corpusData
        self.referenceData = referenceData
        vad = try StrictInputDecoder.vadReport(vadData)
        corpus = try StrictInputDecoder.corpusManifest(corpusData)
        reference = try StrictInputDecoder.referenceManifest(referenceData)
    }
}
