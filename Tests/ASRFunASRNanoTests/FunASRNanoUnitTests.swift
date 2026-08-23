import ASRAPI
@testable import ASRFunASRNano
import Foundation
import Testing
import VADAPI

@Suite("Fun-ASR-Nano adapter")
struct FunASRNanoUnitTests {
    @Test func clampsUnsafeConfigurationValues() {
        let configuration = FunASRNanoConfiguration(
            inferenceThreads: 0,
            minimumRMS: -1,
            maximumNewTokens: 0
        )

        #expect(configuration.inferenceThreads == 1)
        #expect(configuration.minimumRMS == 0)
        #expect(configuration.maximumNewTokens == 1)
    }

    @Test func rejectsIncompleteModelDirectoryBeforeNativeInitialization() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(throws: ASRError.self) {
            _ = try FunASRNanoModelLayout(directory: directory)
        }
    }

    @Test func verifierRejectsMissingFileWithoutLoadingModel() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let verifier = FunASRNanoModelVerifier(
            artifacts: [
                .init(relativePath: "small.bin", byteCount: 4, sha256: Self.goodSHA)
            ]
        )

        #expect(throws: ASRError.self) {
            try verifier.verify(directory: directory)
        }
    }

    @Test func verifierRejectsSameLengthMutationWithoutLoadingModel() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "small.bin")
        let verifier = FunASRNanoModelVerifier(
            artifacts: [
                .init(relativePath: "small.bin", byteCount: 4, sha256: Self.goodSHA)
            ]
        )
        try Data("good".utf8).write(to: url)
        try verifier.verify(directory: directory)
        try Data("evil".utf8).write(to: url)

        #expect(throws: ASRError.self) {
            try verifier.verify(directory: directory)
        }
    }

    @Test func silenceGuardRejectsLowEnergyAndKeepsSpeech() {
        #expect(!FunASRNanoInputGuard.containsSpeech([0, 0, 0], minimumRMS: 0.003))
        #expect(FunASRNanoInputGuard.containsSpeech([0.1, -0.1], minimumRMS: 0.003))
    }

    @Test func repetitionGuardRejectsDecoderLoops() {
        #expect(FunASRNanoOutputGuard.hasPathologicalRepetition(String(repeating: "有", count: 20)))
        #expect(FunASRNanoOutputGuard.hasPathologicalRepetition(String(repeating: "我们有信心", count: 8)))
        #expect(!FunASRNanoOutputGuard.hasPathologicalRepetition("我们有信心，所以继续前行。"))
    }

    @Test func providerRequiresLoadedModel() async {
        let provider = FunASRNanoProvider()
        let segment = SpeechSegment(
            sequenceNumber: 1,
            samples: [0.1, -0.1],
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(1),
            endReason: .trailingSilence
        )

        await #expect(throws: ASRError.self) {
            try await provider.transcribe(ASRRequest(segment: segment))
        }
    }

    private static let goodSHA =
        "770e607624d689265ca6c44884d0807d9b054d23c473c106c72be9de08b7376c"

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
