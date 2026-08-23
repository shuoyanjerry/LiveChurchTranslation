import Foundation

struct QwenEnglishCorpusManifest: Codable, Sendable {
    let schemaVersion: Int
    let generatorRevision: String
    let sourceKind: String
    let generatedAt: String
    let hostOS: String
    let clips: [QwenEnglishCorpusClip]
}

struct QwenEnglishCorpusClip: Codable, Sendable {
    let id: String
    let file: String
    let reference: String
    let voice: String
    let locale: String
    let speakingRate: Int
    let audioSHA256: String
}

struct QwenEnglishClipResult: Codable, Sendable {
    let id: String
    let voice: String
    let locale: String
    let reference: String
    let hypothesis: String
    let audioSeconds: Double
    let decodeSeconds: Double
    let wordEdits: Int
    let referenceWords: Int
    let characterEdits: Int
    let referenceCharacters: Int
}

struct QwenEnglishAggregateResult: Codable, Sendable {
    let clipCount: Int
    let voiceCount: Int
    let localeCount: Int
    let audioSeconds: Double
    let decodeSeconds: Double
    let wordEdits: Int
    let referenceWords: Int
    let characterEdits: Int
    let referenceCharacters: Int
    let wordErrorRate: Double
    let characterErrorRate: Double
    let realTimeFactor: Double

    init(
        clipCount: Int,
        voiceCount: Int,
        localeCount: Int,
        audioSeconds: Double,
        decodeSeconds: Double,
        wordEdits: Int,
        referenceWords: Int,
        characterEdits: Int,
        referenceCharacters: Int
    ) {
        self.clipCount = clipCount
        self.voiceCount = voiceCount
        self.localeCount = localeCount
        self.audioSeconds = audioSeconds
        self.decodeSeconds = decodeSeconds
        self.wordEdits = wordEdits
        self.referenceWords = referenceWords
        self.characterEdits = characterEdits
        self.referenceCharacters = referenceCharacters
        wordErrorRate = referenceWords == 0 ? 1 : Double(wordEdits) / Double(referenceWords)
        characterErrorRate =
            referenceCharacters == 0
            ? 1 : Double(characterEdits) / Double(referenceCharacters)
        realTimeFactor = audioSeconds == 0 ? .infinity : decodeSeconds / audioSeconds
    }
}

struct QwenEnglishQualificationReport: Codable, Sendable {
    let schemaVersion: Int
    let languageCode: String
    let contextPrompt: String
    let gate: QwenEnglishGatePolicy
    let modelRevision: String
    let runtimeRevision: String
    let corpusManifestSHA256: String
    let corpus: QwenEnglishCorpusManifest
    let aggregate: QwenEnglishAggregateResult
    let clips: [QwenEnglishClipResult]
}

struct QwenEnglishGatePolicy: Codable, Sendable {
    let minimumClips: Int
    let minimumVoices: Int
    let minimumLocales: Int
    let maximumWeightedWER: Double
    let maximumWeightedCER: Double
    let maximumClipWER: Double
    let maximumRealTimeFactor: Double
}
