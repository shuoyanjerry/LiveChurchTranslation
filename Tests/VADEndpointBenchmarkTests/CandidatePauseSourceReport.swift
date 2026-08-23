import Foundation

struct CandidatePauseSourceDocument: Decodable {
    let schemaVersion: Int
    let strategies: [CandidatePauseSourceStrategy]

    static func load(
        from url: URL,
        entries: [VADCorpusEntry]
    ) throws -> (document: Self, fingerprint: VADAudioFingerprint) {
        let before = try VADBenchmarkCorpus.fingerprint(url)
        let data = try Data(contentsOf: url, options: [.mappedIfSafe, .uncached])
        let document = try JSONDecoder().decode(Self.self, from: data)
        let after = try VADBenchmarkCorpus.fingerprint(url)
        guard before == after else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("source report changed")
        }
        try document.validate(entries: entries)
        return (document, before)
    }

    var selected: CandidatePauseSourceStrategy {
        strategies[0]
    }

    private func validate(entries: [VADCorpusEntry]) throws {
        guard schemaVersion == 1 else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("unsupported schema")
        }
        guard strategies.count == 1, strategies[0].strategy == "webrtcStable" else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("selected strategy mismatch")
        }
        let files = strategies[0].files
        guard files.count == entries.count else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("clip cardinality mismatch")
        }
        for (index, pair) in zip(files, entries).enumerated() {
            let expectedID = String(format: "sermon-%02d", index + 1)
            guard pair.0.corpusID == expectedID, pair.1.id == expectedID else {
                throw CandidatePauseBenchmarkError.invalidSourceReport("clip order mismatch")
            }
            let fingerprint = try VADBenchmarkCorpus.fingerprint(pair.1.url)
            guard pair.0.sha256 == fingerprint.sha256,
                pair.0.byteCount == fingerprint.byteCount,
                pair.0.sha256.count == 64
            else {
                throw CandidatePauseBenchmarkError.invalidSourceReport("source WAV mismatch")
            }
        }
        guard Set(files.map(\.corpusID)).count == files.count else {
            throw CandidatePauseBenchmarkError.invalidSourceReport("duplicate clip identity")
        }
    }
}

struct CandidatePauseSourceStrategy: Decodable {
    let strategy: String
    let files: [CandidatePauseSourceFile]
}

struct CandidatePauseSourceFile: Decodable {
    let corpusID: String
    let sha256: String
    let byteCount: Int64
    let audioSeconds: Double
    let boundaries: [CandidatePauseSourceBoundary]
}

struct CandidatePauseSourceBoundary: Decodable, Equatable {
    let sequenceNumber: UInt64
    let startedAtSeconds: Double
    let endedAtSeconds: Double
    let durationSeconds: Double
    let reason: String
    let emissionLagAfterRetainedAudioSeconds: Double?
}
