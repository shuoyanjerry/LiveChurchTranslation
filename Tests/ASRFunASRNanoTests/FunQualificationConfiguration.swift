import ASRFunASRNano
import ASRQualificationSupport

enum FunQualificationConfiguration {
    static let frozenManifestSHA256 =
        "8a485214b1c3fe01a931ec52bf14a59d409c3746b4e2e33dd28d0a80858302c8"
    static let hotwords =
        "救恩,恩典,称义,因信称义,成圣,重生,赎罪,三位一体,圣灵,团契,事奉,圣餐,洗礼"
    static let languageCode = "zh"
    static let modelRevision =
        "zengshuishui/FunASR-nano-onnx@2fbcc2ea1b60a2d579f2a8e921cac6023c61789d"
    static let runtimeRevision = "sherpa-onnx@1.13.6"

    static let providerConfiguration = FunASRNanoConfiguration(
        inferenceThreads: 2,
        minimumRMS: 0.003,
        maximumNewTokens: 192,
        language: languageCode,
        staticHotwords: hotwords
    )

    static func providerMetadata(
        verifiedModelRevision: String
    ) -> ASRQualificationProviderMetadataV3 {
        ASRQualificationProviderMetadataV3(
            name: "funaudiollm.fun-asr-nano-2512.sherpa-onnx",
            modelRevision: verifiedModelRevision,
            runtimeRevision: runtimeRevision,
            settings: [
                "artifactVerification": "sixFilesBytesAndSHA256",
                "hotwordPolicy": "constructionTimeStatic",
                "inferenceThreads": "2",
                "languageCode": languageCode,
                "maximumNewTokens": "192",
                "minimumRMS": "0.003",
                "staticHotwords": hotwords,
            ]
        )
    }
}
