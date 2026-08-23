import ASRQualificationSupport
import ASRQwen3

enum QwenQualificationConfiguration {
    static let frozenManifestSHA256 =
        "8a485214b1c3fe01a931ec52bf14a59d409c3746b4e2e33dd28d0a80858302c8"
    static let prompt =
        "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵,团契,事奉,圣餐,洗礼"
    static let languageCode = "zh"
    static let modelRevision = "qwen3-asr-0.6b-int8-2026-03-25"
    static let runtimeRevision = "sherpa-onnx@1.13.6"

    static func providerConfiguration(
        for profile: QwenQualificationProfile
    ) -> Qwen3ASRConfiguration {
        Qwen3ASRConfiguration(
            inferenceThreads: profile.inferenceThreads,
            maximumHotwords: 48,
            minimumRMS: 0.003,
            maximumNewTokens: 192
        )
    }

    static func providerMetadata(
        for profile: QwenQualificationProfile
    ) -> ASRQualificationProviderMetadataV3 {
        ASRQualificationProviderMetadataV3(
            name: "qwen.qwen3-asr.sherpa-onnx",
            modelRevision: modelRevision,
            runtimeRevision: runtimeRevision,
            settings: [
                "artifactVerification": "sixFilesBytesAndSHA256",
                "computeProvider": "cpu",
                "contextPolicy": "glossaryOnly",
                "contextPrompt": prompt,
                "inferenceThreads": String(profile.inferenceThreads),
                "languageCode": languageCode,
                "maximumHotwords": "48",
                "maximumNewTokens": "192",
                "minimumRMS": "0.003",
                "qualificationProfile": profile.rawValue,
                "recognizerMaxTotalLength": "512",
                "samplingSeed": "42",
                "temperature": "0.000001",
                "topP": "0.8",
            ]
        )
    }
}
