import Foundation
import Testing
import TranscriptAPI

extension SourceOnlyPersistenceTests {
    var targetSentinel: String { "TARGET_TRANSLATION_SENTINEL_7F3A" }
    var reviewSentinel: String { "REVIEW_SENTINEL_91CE" }
    var forbiddenTexts: [String] { [targetSentinel, reviewSentinel] }

    func reviewedEntries() throws -> [TranscriptEntry] {
        [
            try addingTranslationReview(to: reviewedFirstEntry()),
            try addingTranslationReview(to: reviewedSecondEntry()),
        ]
    }

    func addingTranslationReview(to entry: TranscriptEntry) throws -> TranscriptEntry {
        let encoder = JSONEncoder()
        var object = try jsonObject(encoder.encode(entry))
        object["translationReview"] = ["issueCodes": [reviewSentinel]]
        return try JSONDecoder().decode(
            TranscriptEntry.self,
            from: JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        )
    }

    func sourceSession(_ id: UUID) -> TranscriptSession {
        TranscriptSession(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            endedAt: nil,
            entries: [],
            title: "主日信息",
            kind: .live,
            sourceLanguage: "zh-Hans",
            targetLanguage: "en"
        )
    }

    func finishedSourceSession(
        _ id: UUID,
        entries: [TranscriptEntry]
    ) -> TranscriptSession {
        TranscriptSession(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1_750_000_000),
            endedAt: Date(timeIntervalSince1970: 1_750_000_010),
            entries: entries,
            title: "主日信息",
            kind: .live,
            sourceLanguage: "zh-Hans",
            targetLanguage: "en"
        )
    }

    func assertSourceEvidence(
        _ expected: [TranscriptEntry],
        survivedIn actual: [TranscriptEntry]
    ) {
        #expect(actual.map(\.id) == expected.map(\.id))
        #expect(actual.map(\.sequence) == expected.map(\.sequence))
        #expect(actual.map(\.sourceSegmentSequence) == expected.map(\.sourceSegmentSequence))
        #expect(actual.map(\.rawSourceText) == expected.map(\.rawSourceText))
        #expect(actual.map(\.sourceText) == expected.map(\.sourceText))
        #expect(actual.map(\.sourceCorrections) == expected.map(\.sourceCorrections))
        #expect(actual.map(\.sourcePronounDecisions) == expected.map(\.sourcePronounDecisions))
        #expect(actual.map(\.startedMilliseconds) == expected.map(\.startedMilliseconds))
        #expect(actual.map(\.endedMilliseconds) == expected.map(\.endedMilliseconds))
        #expect(actual.map(\.createdAt) == expected.map(\.createdAt))
        #expect(actual.allSatisfy { $0.targetText.isEmpty })
        #expect(actual.allSatisfy { $0.translationReview == nil })
        #expect(actual.allSatisfy { $0.translationMilliseconds == 0 })
    }

    func assertSourceOnlyJSONLines(
        at url: URL,
        expectedCount: Int,
        forbiddenTexts: [String]
    ) throws {
        let data = try Data(contentsOf: url)
        let lines = data.split(separator: 0x0A)
        #expect(lines.count == expectedCount)
        for line in lines {
            let object = try jsonObject(Data(line))
            #expect(object["targetText"] == nil)
            #expect(object["translationReview"] == nil)
            #expect(object["translationMilliseconds"] == nil)
        }
        let text = try #require(String(data: data, encoding: .utf8))
        for forbiddenText in forbiddenTexts {
            #expect(!text.contains(forbiddenText))
        }
    }

    func assertSourceOnlyMarkdown(
        at url: URL,
        entries: [TranscriptEntry]
    ) throws {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        #expect(markdown.contains("**识别文字**"))
        #expect(!markdown.contains("**译文**"))
        #expect(!markdown.contains("翻译方向"))
        for entry in entries {
            #expect(markdown.contains(entry.sourceText))
        }
        for forbiddenText in forbiddenTexts {
            #expect(!markdown.contains(forbiddenText))
        }
    }

    func jsonObject(_ data: Data) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func sourceOnlyProjection(of entries: [TranscriptEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var result = Data()
        for entry in entries {
            var object = try jsonObject(encoder.encode(entry))
            object.removeValue(forKey: "targetText")
            object.removeValue(forKey: "translationReview")
            object.removeValue(forKey: "translationMilliseconds")
            result.append(
                try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            )
            result.append(0x0A)
        }
        return result
    }
}
