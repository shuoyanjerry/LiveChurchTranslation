import Foundation
import ScriptureQualificationSupport

final class SyntheticScriptureCorpusFixture {
    let root: URL
    let manifestURL: URL
    private(set) var manifestSHA256: String

    init() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(".artifacts", isDirectory: true)
            .appendingPathComponent("scripture-qualification", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        root = base.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try Self.makeDirectory(root)
        for name in ["declarations", "audio", "reference"] {
            try Self.makeDirectory(root.appendingPathComponent(name, isDirectory: true))
        }
        let englishDeclaration = Data("synthetic English source and use declaration".utf8)
        let chineseDeclaration = Data("synthetic Chinese source and use declaration".utf8)
        let audio = Data("synthetic audio bytes".utf8)
        let reference = Data("original synthetic text, with punctuation.".utf8)
        try Self.write(
            englishDeclaration,
            to: root.appendingPathComponent("declarations/english.txt")
        )
        try Self.write(
            chineseDeclaration,
            to: root.appendingPathComponent("declarations/chinese.txt")
        )
        for id in ["en-development", "zh-development", "en-blind", "zh-blind"] {
            try Self.write(audio, to: root.appendingPathComponent("audio/\(id).wav"))
            try Self.write(reference, to: root.appendingPathComponent("reference/\(id).txt"))
        }
        let hashes = SyntheticScriptureHashes(
            englishDeclaration: ScriptureQualificationSHA256.hash(data: englishDeclaration),
            chineseDeclaration: ScriptureQualificationSHA256.hash(data: chineseDeclaration),
            audio: ScriptureQualificationSHA256.hash(data: audio),
            reference: ScriptureQualificationSHA256.hash(data: reference)
        )
        manifestURL = root.appendingPathComponent("manifest.json")
        manifestSHA256 = ""
        try writeManifest(SyntheticScriptureManifestFactory.make(hashes: hashes))
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func load() throws -> ScriptureQualificationCorpus {
        try ScriptureQualificationCorpusLoader.load(
            manifestURL: manifestURL,
            privateRoot: root,
            expectedManifestSHA256: manifestSHA256,
            now: SyntheticScriptureManifestFactory.now
        )
    }

    func manifestObject() throws -> [String: Any] {
        let data = try Data(contentsOf: manifestURL)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FixtureError.invalidJSON
        }
        return object
    }

    func writeManifestObject(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        try Self.write(data, to: manifestURL)
        manifestSHA256 = ScriptureQualificationSHA256.hash(data: data)
    }

    private func writeManifest(_ manifest: ScriptureQualificationManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        try Self.write(data, to: manifestURL)
        manifestSHA256 = ScriptureQualificationSHA256.hash(data: data)
    }

    private static func makeDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private static func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}

private enum FixtureError: Error {
    case invalidJSON
}
