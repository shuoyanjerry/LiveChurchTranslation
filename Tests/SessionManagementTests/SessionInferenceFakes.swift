import ASRAPI
import Foundation
import TranslationAPI

actor FakeMandarinASRProvider: ASRProvider {
    nonisolated let identifier = "fake-mandarin-asr"
    private let texts: [String]
    private let loadFails: Bool
    private let recognitionFails: Bool
    private let recognitionError: ASRError?
    private var requests: [ASRRequest] = []

    init(
        text: String,
        loadFails: Bool = false,
        recognitionFails: Bool = false,
        recognitionError: ASRError? = nil
    ) {
        texts = [text]
        self.loadFails = loadFails
        self.recognitionFails = recognitionFails
        self.recognitionError = recognitionError
    }

    init(texts: [String]) {
        precondition(!texts.isEmpty)
        self.texts = texts
        loadFails = false
        recognitionFails = false
        recognitionError = nil
    }

    func loadModel(at _: URL) throws {
        if loadFails { throw SessionPipelineFakeError.modelLoading }
    }

    func transcribe(_ request: ASRRequest) throws -> RecognizedUtterance {
        if recognitionFails { throw SessionPipelineFakeError.recognition }
        if let recognitionError { throw recognitionError }
        let text = texts[min(requests.count, max(texts.count - 1, 0))]
        requests.append(request)
        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            text: text,
            confidence: 0.99,
            startedAt: request.segment.startedAt,
            endedAt: request.segment.endedAt
        )
    }

    func unloadModel() {}
    func receivedRequests() -> [ASRRequest] { requests }
}

actor FakeHyTranslationProvider: TranslationProvider {
    nonisolated let identifier = "fake-hy-mt2"
    private let shouldFail: Bool
    private var requests: [TranslationRequest] = []

    init(shouldFail: Bool) { self.shouldFail = shouldFail }
    func loadModel(at _: URL) {}

    func translate(_ request: TranslationRequest) throws -> TranslationResult {
        requests.append(request)
        if shouldFail { throw SessionPipelineFakeError.translation }
        return TranslationResult(
            requestID: request.id,
            sourceText: request.sourceText,
            targetText: "We are justified by faith; this is grace.",
            duration: .milliseconds(35)
        )
    }

    func shutdown() {}
    func receivedRequests() -> [TranslationRequest] { requests }
}
