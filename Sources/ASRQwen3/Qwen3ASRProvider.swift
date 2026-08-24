import ASRAPI
import Foundation
import ModelRuntimeAPI
import SherpaOnnx

/// Sentence-level Mandarin ASR backed by Qwen3-ASR INT8 and sherpa-onnx.
public actor Qwen3ASRProvider: ASRProvider, ModelRuntimeHealthChecking {
    public nonisolated let identifier = "qwen.qwen3-asr.sherpa-onnx"

    private let configuration: Qwen3ASRConfiguration
    private var recognizer: SherpaOnnxOfflineRecognizer?
    private var loadedModelURL: URL?

    public init(configuration: Qwen3ASRConfiguration = .init()) {
        self.configuration = configuration
    }

    public func loadModel(at location: URL) async throws {
        let normalizedLocation = location.standardizedFileURL
        if loadedModelURL == normalizedLocation, recognizer != nil { return }
        let layout = try Qwen3ModelLayout(directory: normalizedLocation)
        recognizer = Qwen3RecognizerFactory.make(
            layout: layout,
            configuration: configuration
        )
        loadedModelURL = normalizedLocation
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
        loadedModelURL = nil
    }

    public func isModelRuntimeReady() -> Bool { recognizer != nil }

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
        guard !ASRInputGuard.isKnownNonspeechHallucination(rawText) else {
            throw ASRError.filteredNonspeech
        }

        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            rawText: rawText,
            text: rawText,
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
        return Qwen3DecodeRetryPolicy.selection(
            firstOutput: first,
            fallbackOutput: decode(request, hotwords: "", recognizer: recognizer),
            hotwords: hotwords,
            reason: retryReason
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
