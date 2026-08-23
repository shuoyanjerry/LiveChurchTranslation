import ASRAPI
import Foundation
import SherpaOnnx

/// Replaceable sentence-level challenger backed by Fun-ASR-Nano-2512 INT8.
public actor FunASRNanoProvider: ASRProvider {
    public nonisolated let identifier = "funaudiollm.fun-asr-nano-2512.sherpa-onnx"

    private let configuration: FunASRNanoConfiguration
    private var recognizer: SherpaOnnxOfflineRecognizer?

    public init(configuration: FunASRNanoConfiguration = .init()) {
        self.configuration = configuration
    }

    public func loadModel(at location: URL) async throws {
        let layout = try FunASRNanoModelLayout(directory: location)
        recognizer = FunASRNanoRecognizerFactory.make(
            layout: layout,
            configuration: configuration
        )
    }

    public func transcribe(_ request: ASRRequest) async throws -> RecognizedUtterance {
        guard let recognizer else { throw ASRError.modelNotLoaded }
        let samples = request.segment.samples
        guard !samples.isEmpty else { throw ASRError.emptyAudio }
        guard
            FunASRNanoInputGuard.containsSpeech(
                samples,
                minimumRMS: configuration.minimumRMS
            )
        else { throw ASRError.filteredNonspeech }

        let result = recognizer.decode(
            samples: samples,
            sampleRate: Int(request.segment.sampleRate)
        )
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ASRError.noSpeechRecognized }
        guard !FunASRNanoOutputGuard.hasPathologicalRepetition(text) else {
            throw ASRError.repetitiveHallucination
        }

        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            rawText: text,
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
