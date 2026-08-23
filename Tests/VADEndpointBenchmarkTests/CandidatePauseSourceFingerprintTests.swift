import Foundation
import Testing

@Suite("Candidate-pause source fingerprints")
struct CandidatePauseSourceFingerprintTests {
    @Test func productionBundleIncludesAndBindsVendoredWebRTCSources() throws {
        let workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let vendored = try CandidatePauseHashing.webRTCVendoredSourceFingerprint(
            workspaceRoot: workspace
        )
        let production = try CandidatePauseHashing.productionSourceFingerprint(
            workspaceRoot: workspace
        )
        let audioProcessing = try CandidatePauseHashing.audioProcessingSourceFingerprint(
            workspaceRoot: workspace
        )
        #expect(vendored.fileCount == 21)
        #expect(audioProcessing.fileCount == 4)
        #expect(production.fileCount == 59)
        #expect(CandidatePauseDigestValidator.isSHA256(vendored.sha256))
        #expect(CandidatePauseDigestValidator.isSHA256(audioProcessing.sha256))

        let fixture = try sourceFingerprintFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let before = try CandidatePauseHashing.productionSourceFingerprint(
            workspaceRoot: fixture.root
        )
        try Data("int fvad(void) { return 1; }".utf8).write(to: fixture.cSource)
        let after = try CandidatePauseHashing.productionSourceFingerprint(
            workspaceRoot: fixture.root
        )
        try Data("struct ProcessedAudioFrame { let duration = 2 }".utf8).write(
            to: fixture.frameSource
        )
        let afterFrameChange = try CandidatePauseHashing.productionSourceFingerprint(
            workspaceRoot: fixture.root
        )
        #expect(before.fileCount == 6)
        #expect(after.fileCount == before.fileCount)
        #expect(after.sha256 != before.sha256)
        #expect(afterFrameChange.sha256 != after.sha256)
    }

    private func sourceFingerprintFixture() throws -> CandidatePauseSourceFixture {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(
            "candidate-pause-source-\(UUID().uuidString)",
            isDirectory: true
        )
        let directories = [
            "Sources/AudioProcessingAPI", "Sources/VADAPI", "Sources/VADCore",
            "Sources/VADWebRTC",
            "Sources/WebRTCVADC/Vendor/libfvad/src",
            "Sources/WebRTCVADC/Vendor/libfvad/include",
        ]
        try createDirectories(directories, under: root, manager: manager)
        for directory in directories.prefix(4) {
            let file = root.appendingPathComponent(directory).appendingPathComponent("source.swift")
            try Data("struct Source {}".utf8).write(to: file)
        }
        let frameSource = root.appendingPathComponent(
            "Sources/AudioProcessingAPI/source.swift"
        )
        let cSource = root.appendingPathComponent(
            "Sources/WebRTCVADC/Vendor/libfvad/src/fvad.c"
        )
        let header = root.appendingPathComponent(
            "Sources/WebRTCVADC/Vendor/libfvad/include/fvad.h"
        )
        try Data("int fvad(void) { return 0; }".utf8).write(to: cSource)
        try Data("int fvad(void);".utf8).write(to: header)
        return CandidatePauseSourceFixture(
            root: root,
            cSource: cSource,
            frameSource: frameSource
        )
    }

    private func createDirectories(
        _ directories: [String],
        under root: URL,
        manager: FileManager
    ) throws {
        for directory in directories {
            try manager.createDirectory(
                at: root.appendingPathComponent(directory),
                withIntermediateDirectories: true
            )
        }
    }
}

private struct CandidatePauseSourceFixture {
    let root: URL
    let cSource: URL
    let frameSource: URL
}
