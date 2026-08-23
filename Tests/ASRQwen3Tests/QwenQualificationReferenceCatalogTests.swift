import Foundation
import Testing

@Suite("Qwen qualification reference catalog")
struct QwenQualificationReferenceCatalogTests {
    @Test("verifies raw SHA before decoding and preserves exact reference text")
    func loadsVerifiedReferenceText() throws {
        let data = try referenceData(id: "fixture-clip", text: "他\n爱世人。")
        let manifest = QwenQualificationTestFixtures.manifest(
            referenceManifestSHA256: QwenQualificationHashing.sha256(data),
            referenceText: "他\n爱世人。"
        )

        let catalog = try QwenQualificationReferenceCatalog.load(data: data, for: manifest)

        #expect(catalog.referencesByID["fixture-clip"] == "他\n爱世人。")
    }

    @Test("rejects an unverified malformed source as a SHA mismatch first")
    func checksSHAFirst() {
        let manifest = QwenQualificationTestFixtures.manifest()

        #expect(throws: QwenQualificationReferenceError.sha256Mismatch) {
            try QwenQualificationReferenceCatalog.load(
                data: Data("not json".utf8),
                for: manifest
            )
        }
    }

    @Test("requires the exact frozen clip ID set")
    func rejectsDifferentClipSet() throws {
        let data = try referenceData(id: "different-clip", text: "他")
        let manifest = QwenQualificationTestFixtures.manifest(
            referenceManifestSHA256: QwenQualificationHashing.sha256(data)
        )

        #expect(throws: QwenQualificationReferenceError.clipSetMismatch) {
            try QwenQualificationReferenceCatalog.load(data: data, for: manifest)
        }
    }

    private func referenceData(id: String, text: String) throws -> Data {
        let object: [String: Any] = [
            "schema_version": 1,
            "corpus_id": "fixture-corpus",
            "clips": [["id": id, "reference_text": text, "ignored_extra": true]],
        ]
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
