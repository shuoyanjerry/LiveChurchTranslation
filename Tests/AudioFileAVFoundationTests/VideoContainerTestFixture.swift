@preconcurrency import AVFoundation
import Foundation

enum VideoFixtureContainer: String, CaseIterable, Sendable {
    case mov
    case mp4
    case m4v

    var fileType: AVFileType {
        switch self {
        case .mov: .mov
        case .mp4: .mp4
        case .m4v: .m4v
        }
    }
}

extension AudioFileTestFixture {
    @MainActor
    func videoFile(
        container: VideoFixtureContainer,
        includesAudio: Bool
    ) async throws -> URL {
        let qualifier = includesAudio ? "with-audio" : "without-audio"
        let outputURL = rootURL.appendingPathComponent(
            "video-\(qualifier).\(container.rawValue)"
        )
        let audioURL: URL?
        if includesAudio {
            audioURL = try audibleToneFile()
        } else {
            audioURL = nil
        }
        return try await VideoFixtureWriter(
            outputURL: outputURL,
            fileType: container.fileType,
            audioURL: audioURL
        ).write()
    }

    private func audibleToneFile() throws -> URL {
        let sampleRate = 44_100.0
        let frameCount = Int(sampleRate * 0.75)
        let samples = (0..<frameCount).map { frame in
            Float(sin(2 * Double.pi * 440 * Double(frame) / sampleRate) * 0.25)
        }
        return try audioFile(
            extension: "caf",
            sampleRate: sampleRate,
            channelCount: 1,
            interleavedSamples: samples
        )
    }
}
