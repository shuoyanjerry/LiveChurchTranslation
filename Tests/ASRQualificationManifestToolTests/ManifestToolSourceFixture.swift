import Foundation

enum ManifestToolSourceFixture {
    static let referenceText = "神爱世人。\n"

    static func corpusData(
        id: String = "clip-a",
        referenceText: String = referenceText,
        mutate: ((inout [String: Any]) -> Void)? = nil
    ) throws -> Data {
        var root: [String: Any] = [
            "schema_version": 1,
            "corpus_id": "public-domain-mandarin-scripture-v1",
            "description": "fixture",
            "license": [
                "audio": "Public Domain",
                "audio_url": "https://example.test/audio",
                "reference": "Public Domain",
                "reference_url": "https://example.test/reference",
            ],
            "reference_bundle_sha256": String(repeating: "a", count: 64),
            "clips": [corpusClip(id: id, referenceText: referenceText)],
        ]
        mutate?(&root)
        return try encode(root)
    }

    static func referenceData(
        id: String = "clip-a",
        referenceText: String = referenceText,
        allowsEdges: Bool = true,
        mutate: ((inout [String: Any]) -> Void)? = nil
    ) throws -> Data {
        var root: [String: Any] = [
            "schema_version": 1,
            "corpus_id": "public-domain-mandarin-scripture-v1",
            "boundary_collar_ms": 250,
            "latency_reference_kind": "fixture",
            "pronoun_reference_kind": "fixture",
            "quality_gates": [:],
            "clips": [
                referenceClip(
                    id: id,
                    referenceText: referenceText,
                    allowsEdges: allowsEdges
                )
            ],
        ]
        mutate?(&root)
        return try encode(root)
    }

    static func documents(
        padding: Int = 0,
        pcmSHA256: String = ManifestToolTestAudio.pcmSHA256(),
        referenceText: String = referenceText,
        allowsEdges: Bool = true
    ) throws -> ManifestToolDocuments {
        try ManifestToolDocuments(
            vadData: ManifestToolVADFixture.data(
                padding: padding,
                pcmSHA256: pcmSHA256
            ),
            corpusData: corpusData(referenceText: referenceText),
            referenceData: referenceData(
                referenceText: referenceText,
                allowsEdges: allowsEdges
            )
        )
    }

    private static func corpusClip(id: String, referenceText: String) -> [String: Any] {
        [
            "id": id,
            "audio_path": "/fixtures/\(id).wav",
            "duration_ms": 0.25,
            "reference_text": referenceText,
            "reference_segments": [referenceText],
            "focus": ["fixture"],
            "source_page": "https://example.test/source",
            "audio_url": "https://example.test/wav",
            "audio_download_sha256": String(repeating: "b", count: 64),
            "reference_entries": ["fixture.txt"],
        ]
    }

    private static func referenceClip(
        id: String,
        referenceText: String,
        allowsEdges: Bool
    ) -> [String: Any] {
        [
            "id": id,
            "duration_ms": 0.25,
            "reference_text": referenceText,
            "reference_segments": [referenceText],
            "asr_ignore_hypothesis_edges": allowsEdges,
            "pronouns": [["id": "p1", "value": "他", "resolvable": true]],
            "translation_checks": [],
        ]
    }

    private static func encode(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
