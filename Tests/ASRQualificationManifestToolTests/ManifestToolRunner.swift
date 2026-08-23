import ASRQualificationSupport
import Foundation

struct ManifestToolRunResult: Equatable, Sendable {
    let corpusID: String
    let clipCount: Int
    let segmentCount: Int
    let outputURL: URL
}

struct ASRQualificationManifestTool {
    let expectedSegmentCount: Int

    init(expectedSegmentCount: Int = 220) {
        self.expectedSegmentCount = expectedSegmentCount
    }

    func run(_ inputs: ManifestToolInputs) throws -> ManifestToolRunResult {
        let documents = try ManifestToolDocuments(
            vadData: read(inputs.vadReportURL, source: "vad"),
            corpusData: read(inputs.corpusManifestURL, source: "corpus"),
            referenceData: read(inputs.referenceManifestURL, source: "reference")
        )
        let build = try ManifestToolBuilder(
            expectedSegmentCount: expectedSegmentCount
        ).make(documents: documents)
        let verifiedCount = try verify(build, wavDirectory: inputs.wavDirectoryURL)
        guard verifiedCount == expectedSegmentCount else {
            throw ManifestToolError.segmentCount(
                expected: expectedSegmentCount,
                actual: verifiedCount
            )
        }
        try write(build.manifest, to: inputs.outputURL)
        return ManifestToolRunResult(
            corpusID: build.manifest.corpusID,
            clipCount: build.manifest.clips.count,
            segmentCount: verifiedCount,
            outputURL: inputs.outputURL
        )
    }

    private func read(_ url: URL, source: String) throws -> Data {
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ManifestToolError.unreadableInput(source)
        }
    }

    private func verify(
        _ build: ManifestToolBuild,
        wavDirectory: URL
    ) throws -> Int {
        let loader = ASRQualificationWAVLoader()
        var count = 0
        for clip in build.manifest.clips {
            guard let fileName = build.fileNamesByClipID[clip.id],
                let expectedBytes = build.byteCountsByClipID[clip.id]
            else {
                throw ManifestToolError.clipSetMismatch(source: "vad")
            }
            let url = wavDirectory.appendingPathComponent(fileName, isDirectory: false)
            let data = try read(url, source: "wav.\(clip.id)")
            guard Int64(data.count) == expectedBytes else {
                throw ManifestToolError.invalidVADFile(clip.id)
            }
            count += try loader.load(clip: clip, from: url).count
        }
        return count
    }

    private func write(
        _ manifest: ASRQualificationManifestV2,
        to outputURL: URL
    ) throws {
        let parent = outputURL.deletingLastPathComponent()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ManifestToolError.outputParentMissing(parent.path)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(manifest)
        data.append(0x0A)
        _ = try ASRQualificationManifestDecoder().decode(data)
        do {
            try data.write(to: outputURL, options: .atomic)
        } catch {
            throw ManifestToolError.outputWriteFailed(outputURL.path)
        }
    }
}
