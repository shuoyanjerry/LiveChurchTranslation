import Foundation

enum QwenEnglishCorpusLoader {
    static func load(from url: URL) throws -> QwenEnglishCorpusManifest {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let manifest = try JSONDecoder().decode(QwenEnglishCorpusManifest.self, from: data)
        try validate(manifest)
        return manifest
    }

    static func validate(_ manifest: QwenEnglishCorpusManifest) throws {
        guard manifest.schemaVersion == 1 else {
            throw QwenEnglishCorpusError.unsupportedSchema(manifest.schemaVersion)
        }
        guard manifest.generatorRevision == "qwen-english-say-v1",
            manifest.sourceKind == "macos-say-synthetic"
        else {
            throw QwenEnglishCorpusError.invalidProvenance
        }
        guard manifest.clips.count >= 18 else {
            throw QwenEnglishCorpusError.insufficientDiversity
        }
        let ids = Set(manifest.clips.map(\.id))
        let voices = Set(manifest.clips.map(\.voice))
        let locales = Set(manifest.clips.map(\.locale))
        guard ids.count == manifest.clips.count, voices.count >= 6, locales.count >= 6 else {
            throw QwenEnglishCorpusError.insufficientDiversity
        }
        try manifest.clips.forEach(validate)
    }

    private static func validate(_ clip: QwenEnglishCorpusClip) throws {
        let path = clip.file as NSString
        guard !clip.id.isEmpty,
            path.lastPathComponent == clip.file,
            path.pathExtension.lowercased() == "wav",
            !clip.reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            clip.reference.contains(where: { $0.isLetter || $0.isNumber }),
            !clip.voice.isEmpty,
            clip.locale.hasPrefix("en_"),
            (120...230).contains(clip.speakingRate),
            isCanonicalSHA256(clip.audioSHA256)
        else {
            throw QwenEnglishCorpusError.invalidClip(clip.id)
        }
    }

    private static func isCanonicalSHA256(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isNumber || ("a"..."f").contains($0) }
    }
}

enum QwenEnglishCorpusError: Error, Equatable {
    case unsupportedSchema(Int)
    case invalidProvenance
    case insufficientDiversity
    case invalidClip(String)
    case audioHashMismatch(String)
    case invalidWave(String)
}
