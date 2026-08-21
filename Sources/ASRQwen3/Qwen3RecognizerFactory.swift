import SherpaOnnx

enum Qwen3RecognizerFactory {
    static func make(
        layout: Qwen3ModelLayout,
        configuration: Qwen3ASRConfiguration
    ) -> SherpaOnnxOfflineRecognizer {
        let qwen = sherpaOnnxOfflineQwen3ASRModelConfig(
            convFrontend: layout.convFrontend.path,
            encoder: layout.encoder.path,
            decoder: layout.decoder.path,
            tokenizer: layout.tokenizer.path,
            maxTotalLen: 512,
            maxNewTokens: configuration.maximumNewTokens,
            temperature: 0.000_001,
            topP: 0.8,
            seed: 42,
            hotwords: ""
        )
        let model = sherpaOnnxOfflineModelConfig(
            tokens: "",
            numThreads: configuration.inferenceThreads,
            provider: "cpu",
            debug: 0,
            qwen3Asr: qwen
        )
        var recognizer = sherpaOnnxOfflineRecognizerConfig(
            featConfig: sherpaOnnxFeatureConfig(sampleRate: 16_000, featureDim: 80),
            modelConfig: model
        )
        return SherpaOnnxOfflineRecognizer(config: &recognizer)
    }
}
