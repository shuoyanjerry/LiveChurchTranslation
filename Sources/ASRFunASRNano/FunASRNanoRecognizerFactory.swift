import SherpaOnnx

enum FunASRNanoRecognizerFactory {
    static func make(
        layout: FunASRNanoModelLayout,
        configuration: FunASRNanoConfiguration
    ) -> SherpaOnnxOfflineRecognizer {
        let funASR = sherpaOnnxOfflineFunASRNanoModelConfig(
            encoderAdaptor: layout.encoderAdaptor.path,
            llm: layout.languageModel.path,
            embedding: layout.embedding.path,
            tokenizer: layout.tokenizer.path,
            maxNewTokens: configuration.maximumNewTokens,
            temperature: 0.000_001,
            topP: 0.8,
            seed: 42,
            language: configuration.language,
            itn: true,
            hotwords: configuration.staticHotwords
        )
        let model = sherpaOnnxOfflineModelConfig(
            tokens: "",
            numThreads: configuration.inferenceThreads,
            provider: "cpu",
            debug: 0,
            funasrNano: funASR
        )
        var recognizer = sherpaOnnxOfflineRecognizerConfig(
            featConfig: sherpaOnnxFeatureConfig(sampleRate: 16_000, featureDim: 80),
            modelConfig: model
        )
        return SherpaOnnxOfflineRecognizer(config: &recognizer)
    }
}
