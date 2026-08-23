import Foundation

struct ASRBenchmarkFixture: Codable, Sendable {
    let name: String
    let speaker: String
    let path: String
    let startSeconds: Double
    let durationSeconds: Double
    let expectedTerms: [String]
}

struct ASRBenchmarkObservation: Codable, Sendable {
    let provider: String
    let fixture: String
    let speaker: String
    let audioSeconds: Double
    let decodeSeconds: Double
    let realTimeFactor: Double
    let rawText: String
    let normalizedText: String
    let expectedTerms: [String]
    let matchedTerms: [String]
    let repetitionDetected: Bool
    let error: String?
}

struct ASRBenchmarkLoad: Codable, Sendable {
    let provider: String
    let seconds: Double
}

struct ASRBenchmarkReport: Codable, Sendable {
    let generatedAt: Date
    let operatingSystem: String
    let processorCount: Int
    let sherpaVersion: String
    let modelAssetRevision: String
    let loads: [ASRBenchmarkLoad]
    let observations: [ASRBenchmarkObservation]
}

struct ASRBenchmarkObservationInput: Sendable {
    let provider: String
    let fixture: ASRBenchmarkFixture
    let audioSeconds: Double
    let elapsed: Double
    let rawText: String
    let normalizedText: String
    let matchedTerms: [String]
    let repetition: Bool
    let error: String?
}

struct ASRBenchmarkObservationContext: Sendable {
    let provider: String
    let fixture: ASRBenchmarkFixture
    let audioSeconds: Double
}
