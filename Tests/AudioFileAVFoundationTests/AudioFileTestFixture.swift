import AVFoundation
import Foundation

struct AudioFileTestFixture {
    let rootURL: URL

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
    }

    func audioFile(
        extension fileExtension: String,
        sampleRate: Double,
        channelCount: Int,
        interleavedSamples: [Float]
    ) throws -> URL {
        precondition(interleavedSamples.count.isMultiple(of: channelCount))
        let url = rootURL.appendingPathComponent("fixture.\(fileExtension)")
        guard
            let format = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: AVAudioChannelCount(channelCount)
            )
        else {
            throw FixtureError.invalidFormat
        }
        let frameCount = interleavedSamples.count / channelCount
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(frameCount)
            ), let channels = buffer.floatChannelData
        else {
            throw FixtureError.invalidBuffer
        }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        for frame in 0..<frameCount {
            for channel in 0..<channelCount {
                channels[channel][frame] = interleavedSamples[frame * channelCount + channel]
            }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        return url
    }

    func spokenAudioFile(for testCase: SpokenAudioFixtureCase) throws -> URL {
        let sourceURL = rootURL.appendingPathComponent("spoken-source.aiff")
        try run(
            executable: "/usr/bin/say",
            arguments: [
                "-v", testCase.language.voice,
                "-r", "220",
                "-o", sourceURL.path,
                testCase.language.phrase,
            ]
        )
        let outputURL = rootURL.appendingPathComponent("fixture.\(testCase.format.fileExtension)")
        try run(
            executable: "/usr/bin/afconvert",
            arguments: [sourceURL.path, outputURL.path] + testCase.format.afconvertArguments
        )
        try testCase.format.validateSignature(at: outputURL)
        return outputURL
    }

    static var canQualifyMP3: Bool {
        providedMP3Path != nil || canEncodeMP3
    }

    func mp3AudioFile() throws -> URL {
        if let path = Self.providedMP3Path {
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FixtureError.missingFixture
            }
            try AudioFixtureFormat.mp3.validateSignature(at: url)
            return url
        }
        return try spokenAudioFile(for: .mp3)
    }
}

extension AudioFileTestFixture {
    private static var providedMP3Path: String? {
        guard let path = ProcessInfo.processInfo.environment["AUDIO_IMPORT_MP3_FIXTURE"],
            !path.isEmpty
        else { return nil }
        return path
    }

    private static var canEncodeMP3: Bool {
        guard let fixture = try? AudioFileTestFixture() else { return false }
        defer { fixture.remove() }
        return (try? fixture.spokenAudioFile(for: .mp3)) != nil
    }

    func invalidFile() throws -> URL {
        let url = rootURL.appendingPathComponent("invalid.mp3")
        try Data("not audio".utf8).write(to: url, options: .atomic)
        return url
    }

    func securityScopedURL(for url: URL) throws -> URL {
        let bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var isStale = false
        let resolved = try URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard !isStale else { throw FixtureError.staleBookmark }
        guard resolved.startAccessingSecurityScopedResource() else {
            throw FixtureError.securityScopeUnavailable
        }
        resolved.stopAccessingSecurityScopedResource()
        return resolved
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    private func run(executable: String, arguments: [String]) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let decoded =
                String(bytes: data, encoding: .utf8)
                ?? String(bytes: data, encoding: .isoLatin1)
                ?? ""
            let detail = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
            throw FixtureError.toolFailed(executable, process.terminationStatus, detail)
        }
    }
}

enum FixtureError: Error {
    case invalidFormat
    case invalidBuffer
    case invalidSignature(String)
    case missingFixture
    case securityScopeUnavailable
    case staleBookmark
    case toolFailed(String, Int32, String)
}
