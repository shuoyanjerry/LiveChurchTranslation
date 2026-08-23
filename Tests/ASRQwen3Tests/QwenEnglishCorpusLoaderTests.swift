import Testing

@Suite("Qwen English corpus manifest")
struct QwenEnglishCorpusLoaderTests {
    @Test("accepts the minimum diverse synthetic corpus")
    func acceptsDiverseCorpus() throws {
        try QwenEnglishCorpusLoader.validate(manifest())
    }

    @Test("rejects traversal and insufficient voice diversity")
    func rejectsUnsafeOrHomogeneousCorpus() {
        var clips = manifest().clips
        clips[0] = clip(index: 0, voice: "Samantha", file: "../escape.wav")
        #expect(throws: QwenEnglishCorpusError.self) {
            try QwenEnglishCorpusLoader.validate(manifest(clips: clips))
        }

        clips = (0..<18).map { clip(index: $0, voice: "Samantha") }
        #expect(throws: QwenEnglishCorpusError.insufficientDiversity) {
            try QwenEnglishCorpusLoader.validate(manifest(clips: clips))
        }
    }

    private func manifest(
        clips: [QwenEnglishCorpusClip]? = nil
    ) -> QwenEnglishCorpusManifest {
        QwenEnglishCorpusManifest(
            schemaVersion: 1,
            generatorRevision: "qwen-english-say-v1",
            sourceKind: "macos-say-synthetic",
            generatedAt: "2026-08-22T00:00:00Z",
            hostOS: "test",
            clips: clips ?? (0..<18).map { clip(index: $0, voice: "voice-\($0)") }
        )
    }

    private func clip(
        index: Int,
        voice: String,
        file: String? = nil
    ) -> QwenEnglishCorpusClip {
        QwenEnglishCorpusClip(
            id: "clip-\(index)",
            file: file ?? "clip-\(index).wav",
            reference: "Grace changes how the church serves its neighbors.",
            voice: voice,
            locale: "en_\(index)",
            speakingRate: 180,
            audioSHA256: String(repeating: "a", count: 64)
        )
    }
}
