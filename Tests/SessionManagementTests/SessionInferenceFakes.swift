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
    private let recognitionErrorsByIndex: [Int: ASRError]
    private let recognitionDelay: Duration?
    private var requests: [ASRRequest] = []
    private var loads = 0
    private var runtimeIsReady = false

    init(
        text: String,
        loadFails: Bool = false,
        recognitionFails: Bool = false,
        recognitionError: ASRError? = nil,
        recognitionErrorsByIndex: [Int: ASRError] = [:],
        recognitionDelay: Duration? = nil
    ) {
        texts = [text]
        self.loadFails = loadFails
        self.recognitionFails = recognitionFails
        self.recognitionError = recognitionError
        self.recognitionErrorsByIndex = recognitionErrorsByIndex
        self.recognitionDelay = recognitionDelay
    }

    init(texts: [String]) {
        precondition(!texts.isEmpty)
        self.texts = texts
        loadFails = false
        recognitionFails = false
        recognitionError = nil
        recognitionErrorsByIndex = [:]
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
        if let indexedError = recognitionErrorsByIndex[requestIndex] { throw indexedError }
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
    private let rejectedRequestIndices: Set<Int>
    private let reviewedRequestIndices: Set<Int>
    private let outputs: [String]?
    private var requests: [TranslationRequest] = []
    private var loads = 0
    private var runtimeChecks = 0
    private var runtimeIsReady = false

    init(
        shouldFail: Bool,
        rejectsFirstOutput: Bool = false,
        rejectedRequestIndices: Set<Int> = [],
        reviewedRequestIndices: Set<Int> = [],
        outputs: [String]? = nil
    ) {
        self.shouldFail = shouldFail
        self.rejectedRequestIndices =
            rejectedRequestIndices.union(rejectsFirstOutput ? [0] : [])
        self.reviewedRequestIndices = reviewedRequestIndices
        self.outputs = outputs
    }
    func loadModel(at _: URL) {
        loads += 1
        runtimeIsReady = true
    }

    func translate(_ request: TranslationRequest) throws -> TranslationResult {
        let requestIndex = requests.count
        requests.append(request)
        if shouldFail { throw SessionPipelineFakeError.translation }
        if rejectedRequestIndices.contains(requestIndex) {
            throw TranslationProviderError.invalidOutput
        }
        let targetText: String
        if let outputs, !outputs.isEmpty {
            targetText = outputs[min(requestIndex, outputs.count - 1)]
        } else {
            targetText = "We are justified by faith; this is grace."
        }
        return TranslationResult(
            requestID: request.id,
            sourceText: request.sourceText,
            targetText: targetText,
            duration: .milliseconds(35),
            review: reviewedRequestIndices.contains(requestIndex)
                ? TranslationReview(issueCodes: ["quality.pronoun_alignment"])
                : nil
        )
    }

    func shutdown() { runtimeIsReady = false }
    func isModelRuntimeReady() -> Bool {
        runtimeChecks += 1
        return runtimeIsReady
    }
    func markRuntimeUnavailable() { runtimeIsReady = false }
    func loadCount() -> Int { loads }
    func runtimeCheckCount() -> Int { runtimeChecks }
    func receivedRequests() -> [TranslationRequest] { requests }
}
