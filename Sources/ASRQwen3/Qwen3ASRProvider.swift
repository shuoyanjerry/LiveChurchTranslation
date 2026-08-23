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
            throw ASRError.filteredNonspeech
        }

        let hotwords = ASRInputGuard.hotwords(
            from: request.contextPrompt,
            limit: configuration.maximumHotwords
        )
        let selection = decodeWithSingleFallback(
            request,
            hotwords: hotwords,
            recognizer: recognizer
        )
        return try recognizedUtterance(from: selection, request: request)
    }

    public func unloadModel() async {
        recognizer = nil
    }

    private func recognizedUtterance(
        from selection: Qwen3DecodeSelection,
        request: ASRRequest
    ) throws -> RecognizedUtterance {
        let rawText = selection.rawText
        guard !rawText.isEmpty else { throw ASRError.noSpeechRecognized }
        guard !ASROutputGuard.hasPathologicalRepetition(rawText) else {
            throw ASRError.repetitiveHallucination
        }
        guard
            !ASRInputGuard.isPromptOnlyHallucination(
                rawText,
                hotwords: selection.outputGuardHotwords
            )
        else { throw ASRError.promptOnlyHallucination }
        let text = ASRInputGuard.removingPromptEchoPrefix(
            rawText,
            hotwords: selection.outputGuardHotwords
        )
        guard !text.isEmpty else { throw ASRError.promptOnlyHallucination }
        guard !ASRInputGuard.isKnownNonspeechHallucination(text) else {
            throw ASRError.filteredNonspeech
        }

        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            rawText: rawText,
            text: text,
            confidence: nil,
            startedAt: request.segment.startedAt,
            endedAt: request.segment.endedAt
        )
    }

    private func decodeWithSingleFallback(
        _ request: ASRRequest,
        hotwords: String,
        recognizer: SherpaOnnxOfflineRecognizer
    ) -> Qwen3DecodeSelection {
        let first = decode(request, hotwords: hotwords, recognizer: recognizer)
        guard
            let retryReason = Qwen3DecodeRetryPolicy.retryReason(
                firstOutput: first,
                hotwords: hotwords
            )
        else {
            return Qwen3DecodeSelection(rawText: first, outputGuardHotwords: hotwords)
        }
        return Qwen3DecodeSelection(
            rawText: decode(request, hotwords: "", recognizer: recognizer),
            outputGuardHotwords: Qwen3DecodeRetryPolicy.outputGuardHotwords(
                after: retryReason,
                originalHotwords: hotwords
            )
        )
    }

    private func decode(
        _ request: ASRRequest,
        hotwords: String,
        recognizer: SherpaOnnxOfflineRecognizer
    ) -> String {
        let stream = recognizer.createStream()
        stream.setOption(key: "language", value: request.languageCode)
        stream.setOption(key: "hotwords", value: hotwords)
        stream.acceptWaveform(
            samples: request.segment.samples,
            sampleRate: Int(request.segment.sampleRate)
        )
        recognizer.decode(stream: stream)
        return recognizer.getResult(stream: stream).text
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
