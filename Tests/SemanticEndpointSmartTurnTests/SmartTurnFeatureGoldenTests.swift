@testable import SemanticEndpointSmartTurn
import Foundation
import Testing

@Suite("Whisper feature parity")
struct SmartTurnFeatureGoldenTests {
    @Test("matches official Transformers goldens", arguments: ["silence", "sine", "mixed"])
    func matchesOfficialGolden(caseName: String) throws {
        let fixture = try Self.loadFixture()
        let golden = try #require(fixture.cases.first { $0.name == caseName })
        let samples = try Self.samples(named: caseName)
        #expect(samples.count == golden.sampleCount)
        let features = try SmartTurnWhisperFeatureExtractor().extract(samples)
        #expect(features.count == 80 * 800)
        for (index, coordinate) in fixture.coordinates.enumerated() {
            let melIndex = try #require(coordinate.first)
            let frameIndex = try #require(coordinate.last)
            let actual = features[(melIndex * 800) + frameIndex]
            #expect(abs(actual - golden.selected[index]) < 0.000_002)
        }
        let statistics = Self.statistics(features)
        #expect(abs(statistics.minimum - golden.statistics.minimum) < 0.000_002)
        #expect(abs(statistics.maximum - golden.statistics.maximum) < 0.000_002)
        #expect(abs(statistics.mean - golden.statistics.mean) < 0.000_002)
        #expect(abs(statistics.standardDeviation - golden.statistics.standardDeviation) < 0.000_002)
        #expect(abs(statistics.sum - golden.statistics.sum) < 0.02)
    }

    @Test("keeps only the last eight seconds")
    func discardsOldPrefix() throws {
        let original = TestWaveforms.mixedSpeechLike()
        var changedPrefix = original
        changedPrefix.replaceSubrange(
            0..<(2 * TestWaveforms.sampleRate), with: repeatElement(-0.7, count: 32_000))
        let extractor = SmartTurnWhisperFeatureExtractor()
        #expect(try extractor.extract(original) == extractor.extract(changedPrefix))
    }

    private static func samples(named name: String) throws -> [Float] {
        switch name {
        case "silence": TestWaveforms.silence()
        case "sine": TestWaveforms.sine()
        case "mixed": TestWaveforms.mixedSpeechLike()
        default: throw CocoaError(.fileReadUnknown)
        }
    }

    private static func loadFixture() throws -> GoldenFixture {
        let location = try #require(
            Bundle.module.url(
                forResource: "whisper_feature_goldens",
                withExtension: "json"
            )
        )
        return try JSONDecoder().decode(GoldenFixture.self, from: Data(contentsOf: location))
    }

    private static func statistics(_ values: [Float]) -> GoldenStatistics {
        let doubles = values.map(Double.init)
        let sum = doubles.reduce(0, +)
        let mean = sum / Double(doubles.count)
        let variance =
            doubles.reduce(0) { $0 + (($1 - mean) * ($1 - mean)) }
            / Double(doubles.count)
        return GoldenStatistics(
            minimum: doubles.min() ?? 0,
            maximum: doubles.max() ?? 0,
            mean: mean,
            standardDeviation: sqrt(variance),
            sum: sum
        )
    }
}

private struct GoldenFixture: Decodable {
    let coordinates: [[Int]]
    let cases: [GoldenCase]
}

private struct GoldenCase: Decodable {
    let name: String
    let sampleCount: Int
    let selected: [Float]
    let statistics: GoldenStatistics
}

private struct GoldenStatistics: Codable {
    let minimum: Double
    let maximum: Double
    let mean: Double
    let standardDeviation: Double
    let sum: Double
}
