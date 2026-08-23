import Foundation

struct ManifestToolWorkspace {
    let root: URL
    let wavDirectory: URL
    let vadURL: URL
    let corpusURL: URL
    let referenceURL: URL
    let outputURL: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        wavDirectory = root.appendingPathComponent("wav", isDirectory: true)
        vadURL = root.appendingPathComponent("vad.json")
        corpusURL = root.appendingPathComponent("corpus.json")
        referenceURL = root.appendingPathComponent("reference.json")
        outputURL = root.appendingPathComponent("output.json")
        try FileManager.default.createDirectory(
            at: wavDirectory,
            withIntermediateDirectories: true
        )
    }

    var inputs: ManifestToolInputs {
        ManifestToolInputs(
            vadReportURL: vadURL,
            corpusManifestURL: corpusURL,
            referenceManifestURL: referenceURL,
            wavDirectoryURL: wavDirectory,
            outputURL: outputURL
        )
    }

    func writeInputs(pcmSHA256: String = ManifestToolTestAudio.pcmSHA256()) throws {
        try ManifestToolVADFixture.data(pcmSHA256: pcmSHA256).write(to: vadURL)
        try ManifestToolSourceFixture.corpusData().write(to: corpusURL)
        try ManifestToolSourceFixture.referenceData().write(to: referenceURL)
        try ManifestToolTestAudio.wav().write(
            to: wavDirectory.appendingPathComponent("clip-a.wav")
        )
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}
