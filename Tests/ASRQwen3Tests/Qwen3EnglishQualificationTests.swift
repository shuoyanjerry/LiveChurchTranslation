import Foundation
import Testing

@Suite("Qwen3 English synthetic-corpus qualification")
struct Qwen3EnglishQualificationTests {
    @Test(
        "meets weighted English WER and CER compatibility floors with languageCode en",
        .enabled(if: Self.hasEnvironment, "Requires model, generated corpus, and report paths.")
    )
    func qualifiesGeneratedEnglishCorpus() async throws {
        let environment = ProcessInfo.processInfo.environment
        let modelURL = try Self.requiredURL("QWEN_MODEL_DIR", environment)
        let manifestURL = try Self.requiredURL("QWEN_ENGLISH_CORPUS_MANIFEST", environment)
        let reportURL = try Self.requiredURL("QWEN_ENGLISH_ASR_REPORT", environment)
        let report = try await QwenEnglishQualificationRunner().run(
            modelDirectory: modelURL,
            manifestURL: manifestURL
        )
        try Self.write(report, to: reportURL)

        print("QWEN_ENGLISH_CLIPS=\(report.aggregate.clipCount)")
        print("QWEN_ENGLISH_VOICES=\(report.aggregate.voiceCount)")
        print("QWEN_ENGLISH_LOCALES=\(report.aggregate.localeCount)")
        print("QWEN_ENGLISH_CONTEXT_PROMPT=\(report.contextPrompt)")
        print("QWEN_ENGLISH_AUDIO_SECONDS=\(report.aggregate.audioSeconds)")
        print("QWEN_ENGLISH_WER=\(report.aggregate.wordErrorRate)")
        print("QWEN_ENGLISH_CER=\(report.aggregate.characterErrorRate)")
        print("QWEN_ENGLISH_RTF=\(report.aggregate.realTimeFactor)")
        for clip in report.clips {
            print("QWEN_ENGLISH_RESULT[\(clip.id)]=\(clip.hypothesis)")
        }

        #expect(report.languageCode == "en")
        #expect(report.contextPrompt == QwenEnglishQualificationRunner.prompt)
        #expect(report.aggregate.clipCount >= report.gate.minimumClips)
        #expect(report.aggregate.voiceCount >= report.gate.minimumVoices)
        #expect(report.aggregate.localeCount >= report.gate.minimumLocales)
        #expect(report.aggregate.wordErrorRate <= report.gate.maximumWeightedWER)
        #expect(report.aggregate.characterErrorRate <= report.gate.maximumWeightedCER)
        #expect(report.aggregate.realTimeFactor <= report.gate.maximumRealTimeFactor)
        for clip in report.clips {
            let clipWER = Double(clip.wordEdits) / Double(clip.referenceWords)
            #expect(clipWER <= report.gate.maximumClipWER)
        }
    }

    private static var hasEnvironment: Bool {
        let environment = ProcessInfo.processInfo.environment
        return [
            "QWEN_MODEL_DIR", "QWEN_ENGLISH_CORPUS_MANIFEST", "QWEN_ENGLISH_ASR_REPORT",
        ].allSatisfy { !(environment[$0] ?? "").isEmpty }
    }

    private static func requiredURL(
        _ key: String,
        _ environment: [String: String]
    ) throws -> URL {
        guard let value = environment[key], !value.isEmpty else {
            throw QwenQualificationInputError.missingEnvironment(key)
        }
        return URL(fileURLWithPath: value).standardizedFileURL
    }

    private static func write(
        _ report: QwenEnglishQualificationReport,
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(report)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
