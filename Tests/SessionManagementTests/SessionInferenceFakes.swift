import ASRAPI
import Foundation
import ModelRuntimeAPI
import TranslationAPI

actor FakeMandarinASRProvider: ASRProvider, ModelRuntimeHealthChecking {
    nonisolated let identifier = "fake-mandarin-asr"
    private let texts: [String]
    private let loadFails: Bool
    private let recognitionFails: Bool
    private let recognitionError: ASRError?
    private let recognitionDelay: Duration?
    private var requests: [ASRRequest] = []
    private var loads = 0
    private var runtimeIsReady = false

    init(
        text: String,
        loadFails: Bool = false,
        recognitionFails: Bool = false,
        recognitionError: ASRError? = nil,
        recognitionDelay: Duration? = nil
    ) {
        texts = [text]
        self.loadFails = loadFails
        self.recognitionFails = recognitionFails
        self.recognitionError = recognitionError
        self.recognitionDelay = recognitionDelay
    }

    init(texts: [String]) {
        precondition(!texts.isEmpty)
        self.texts = texts
        loadFails = false
        recognitionFails = false
        recognitionError = nil
        recognitionDelay = nil
    }

    func loadModel(at _: URL) throws {
        loads += 1
        if loadFails { throw SessionPipelineFakeError.modelLoading }
        runtimeIsReady = true
    }

    func transcribe(_ request: ASRRequest) async throws -> RecognizedUtterance {
        let requestIndex = requests.count
        requests.append(request)
        if let recognitionDelay { try await Task.sleep(for: recognitionDelay) }
        if recognitionFails { throw SessionPipelineFakeError.recognition }
        if let recognitionError { throw recognitionError }
        let text = texts[min(requestIndex, max(texts.count - 1, 0))]
        return RecognizedUtterance(
            sourceSegmentID: request.segment.id,
            text: text,
            confidence: 0.99,
            startedAt: request.segment.startedAt,
            endedAt: request.segment.endedAt
        )
    }

    func unloadModel() { runtimeIsReady = false }
    func isModelRuntimeReady() -> Bool { runtimeIsReady }
    func loadCount() -> Int { loads }
    func receivedRequests() -> [ASRRequest] { requests }
}

actor FakeHyTranslationProvider: TranslationProvider, ModelRuntimeHealthChecking {
    nonisolated let identifier = "fake-hy-mt2"
    private let shouldFail: Bool
    private var requests: [TranslationRequest] = []
    private var loads = 0
    private var runtimeIsReady = false

    init(shouldFail: Bool) { self.shouldFail = shouldFail }
    func loadModel(at _: URL) {
        loads += 1
        runtimeIsReady = true
    }

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

    func shutdown() { runtimeIsReady = false }
    func isModelRuntimeReady() -> Bool { runtimeIsReady }
    func markRuntimeUnavailable() { runtimeIsReady = false }
    func loadCount() -> Int { loads }
    func receivedRequests() -> [TranslationRequest] { requests }
}
