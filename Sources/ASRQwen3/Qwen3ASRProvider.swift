import ASRAPI
import Foundation
import SherpaOnnx

/// Sentence-level Mandarin ASR backed by Qwen3-ASR INT8 and sherpa-onnx.
public actor Qwen3ASRProvider: ASRProvider {
    public nonisolated let identifier = "qwen.qwen3-asr.sherpa-onnx"

    private let configuration: Qwen3ASRConfiguration
    private var recognizer: SherpaOnnxOfflineRecognizer?

    public init(configuration: Qwen3ASRConfiguration = .init()) {
        self.configuration = configuration
    }

    public func loadModel(at location: URL) async throws {
        let layout = try Qwen3ModelLayout(directory: location)
        recognizer = Qwen3RecognizerFactory.make(
            layout: layout,
            configuration: configuration
        )
    }

    public func transcribe(_ request: ASRRequest) async throws -> RecognizedUtterance {
        guard let recognizer else { throw ASRError.modelNotLoaded }
        let samples = request.segment.samples
        guard !samples.isEmpty else { throw ASRError.emptyAudio }
        guard ASRInputGuard.containsSpeech(samples, minimumRMS: configuration.minimumRMS) else {
            throw ASRError.noSpeechRecognized
        }

        let stream = recognizer.createStream()
        stream.setOption(key: "language", value: request.languageCode)
        stream.setOption(
            key: "hotwords",
            value: ASRInputGuard.hotwords(
                from: request.contextPrompt,
                limit: configuration.maximumHotwords
            )
        )
        stream.acceptWaveform(samples: samples, sampleRate: Int(request.segment.sampleRate))
        recognizer.decode(stream: stream)
        let text = recognizer.getResult(stream: stream).text
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ASRError.noSpeechRecognized }

        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            text: text,
            confidence: nil,
            startedAt: request.segment.startedAt,
            endedAt: request.segment.endedAt
        )
    }

    public func unloadModel() async {
        recognizer = nil
    }
}
