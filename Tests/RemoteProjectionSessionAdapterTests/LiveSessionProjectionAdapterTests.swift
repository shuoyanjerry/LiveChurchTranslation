import AudioCaptureAPI
import Foundation
import RemoteProjectionSessionAdapter
import RemoteSharingAPI
import SessionManagementAPI
import Testing
import TranscriptAPI

@Suite("Live session projection adapter")
struct LiveSessionProjectionAdapterTests {
    @Test("Projects the current snapshot and redacts local failure detail")
    func projectsSnapshotAndRedactsFailure() async throws {
        let entry = makeEntry()
        let sessionID = UUID()
        let controller = ProjectionSessionControllerFake(
            initial: LiveSessionSnapshot(
                sessionID: sessionID,
                phase: .listening,
                transcript: [entry],
                sourceLanguage: "zh-Hans",
                targetLanguage: "en",
                modelStatus: nil,
                statusMessage: "Listening"
            )
        )
        let projection = ProjectionUpdateFake()
        let adapter = LiveSessionProjectionAdapter(
            controller: controller,
            projection: projection
        )

        await adapter.start()
        try await waitUntil { await projection.entries().count == 1 }
        await controller.emit(.transcriptAppended(entry))
        await controller.emit(.stateChanged(makeFailedSnapshot(entry: entry)))
        try await waitUntil { await projection.messages().last == "已暂停" }

        #expect(await projection.sessions() == [sessionID])
        try await assertProjectedEntry(projection)
        #expect((await projection.messages()).contains("直播中"))
        #expect(!(await projection.messages()).contains { $0.contains("/Users/") })
    }

    @Test("Does not project per-segment recognition failures")
    func doesNotProjectRecognitionFailureDetails() async throws {
        let sessionID = UUID()
        let controller = ProjectionSessionControllerFake(
            initial: makeListeningSnapshot(sessionID: sessionID)
        )
        let projection = ProjectionUpdateFake()
        let adapter = LiveSessionProjectionAdapter(controller: controller, projection: projection)

        await adapter.start()
        try await waitUntil { await projection.messages().count == 1 }
        await emitRecognitionFailures(controller, sessionID: sessionID)
        try await waitUntil {
            let messages = await projection.messages()
            return messages.count >= 2 && messages.last == "直播中"
        }

        #expect(await projection.entries().isEmpty)
        #expect(await projection.messages() == ["直播中", "直播中"])
        #expect(
            !(await projection.messages()).contains {
                $0.contains("asr.") || $0.contains("/Users/")
            }
        )
    }

}

extension LiveSessionProjectionAdapterTests {
    private func assertProjectedEntry(_ projection: ProjectionUpdateFake) async throws {
        let entries = await projection.entries()
        let entry = try #require(entries.first)
        let languagePair = try #require(await projection.languagePairs().first)

        #expect(entries.count == 1)
        #expect(languagePair.0 == "zh-Hans")
        #expect(languagePair.1 == "en")
        #expect(entry.sourceText == "救恩本乎恩典。基督是主。我们一同祷告。")
        #expect(entry.targetText == "Salvation is by grace. Christ is Lord. Let us pray together.")
        #expect(entry.sourceLanguage == "zh-Hans")
        #expect(entry.targetLanguage == "en")
        #expect(entry.startedMilliseconds == 0)
    }

    private func emitRecognitionFailures(
        _ controller: ProjectionSessionControllerFake,
        sessionID: UUID
    ) async {
        await controller.emit(
            .recoverableError("asr.filtered_nonspeech /Users/private/pending.wav")
        )
        await controller.emit(
            .stateChanged(makeRecognitionFailureSnapshot(sessionID: sessionID))
        )
    }

    private func makeListeningSnapshot(sessionID: UUID) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: .listening,
            transcript: [],
            sourceLanguage: "zh-Hans",
            targetLanguage: "en",
            modelStatus: nil,
            statusMessage: "正在聆听"
        )
    }

    private func makeRecognitionFailureSnapshot(sessionID: UUID) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: sessionID,
            phase: .listening,
            transcript: [],
            sourceLanguage: "zh-Hans",
            targetLanguage: "en",
            modelStatus: nil,
            statusMessage: "asr.filtered_nonspeech",
            issues: [
                LiveSessionIssue(
                    stage: .recognition,
                    utteranceSequence: 7,
                    message: "asr.filtered_nonspeech /Users/private/pending.wav",
                    isRecoverable: false
                )
            ]
        )
    }

    private func makeEntry() -> TranscriptEntry {
        TranscriptEntry(
            sequence: 1,
            sourceText: "救恩本乎恩典。基督是主。我们一同祷告。",
            targetText: "Salvation is by grace. Christ is Lord. Let us pray together.",
            startedMilliseconds: 0,
            endedMilliseconds: 1_000,
            translationMilliseconds: 50
        )
    }

    private func makeFailedSnapshot(entry: TranscriptEntry) -> LiveSessionSnapshot {
        LiveSessionSnapshot(
            sessionID: nil,
            phase: .failed(message: "/Users/private/model.gguf"),
            transcript: [entry],
            modelStatus: nil,
            statusMessage: "/Users/private/model.gguf"
        )
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ProjectionAdapterTestError.timedOut
    }
}
