import AudioImportAPI
import Foundation
@testable import LiveReader
import PersistenceAPI
import SettingsAPI
import Testing

@Suite @MainActor struct SessionLibraryRetranscriptionTests {
    @Test func retainedRecordingCreatesAndSelectsANewTranscript() async throws {
        let fixture = try RetranscriptionFixture(mode: .englishToSimplifiedChinese)
        defer { fixture.remove() }
        let imported = librarySummary()
        let recorder = RetranscriptionCallRecorder()
        let importer = RetranscriptionImporterFake { url, mode, title in
            await recorder.record(url: url, mode: mode, title: title)
            await fixture.store.add(imported)
        }

        await fixture.viewModel.retranscribeRetainedRecording(
            for: fixture.summary,
            using: importer,
            liveSessionIsRunning: false
        )

        let call = try #require(await recorder.calls().only)
        #expect(call.url == fixture.recordingURL)
        #expect(call.mode == .englishToSimplifiedChinese)
        #expect(call.title == "主日信息（重新听抄）")
        #expect(fixture.viewModel.selectedSessionID == imported.id)
        #expect(fixture.viewModel.sessions.map(\.id).contains(fixture.summary.id))
        #expect(fixture.viewModel.sessions.map(\.id).contains(imported.id))
    }

    @Test func sessionWithoutMissingSegmentsIsIgnored() async throws {
        let fixture = try RetranscriptionFixture(
            integrity: .incomplete,
            pendingRecordCount: 0,
            rejectedSentenceCount: 0
        )
        defer { fixture.remove() }
        let recorder = RetranscriptionCallRecorder()

        await fixture.viewModel.retranscribeRetainedRecording(
            for: fixture.summary,
            using: RetranscriptionImporterFake(record: recorder),
            liveSessionIsRunning: false
        )

        #expect(await recorder.calls().isEmpty)
    }

    @Test func missingOrSymbolicRecordingIsNeverRead() async throws {
        for usesSymbolicLink in [false, true] {
            let fixture = try RetranscriptionFixture(createRecording: false)
            defer { fixture.remove() }
            if usesSymbolicLink {
                let target = fixture.directory.appending(path: "outside.caf")
                try Data([0, 1]).write(to: target)
                try FileManager.default.createSymbolicLink(
                    at: fixture.recordingURL,
                    withDestinationURL: target
                )
            }
            let recorder = RetranscriptionCallRecorder()

            await fixture.viewModel.retranscribeRetainedRecording(
                for: fixture.summary,
                using: RetranscriptionImporterFake(record: recorder),
                liveSessionIsRunning: false
            )

            #expect(await recorder.calls().isEmpty)
            #expect(
                fixture.viewModel.presentedError
                    == "完整录音暂时无法打开。现有资料没有受到影响。"
            )
        }
    }

}

extension SessionLibraryRetranscriptionTests {
    @Test func activeSessionAndUnknownDirectionAreRejectedBeforeImport() async throws {
        let active = try RetranscriptionFixture()
        defer { active.remove() }
        await active.store.setActive(true, sessionID: active.summary.id)
        let recorder = RetranscriptionCallRecorder()

        await active.viewModel.retranscribeRetainedRecording(
            for: active.summary,
            using: RetranscriptionImporterFake(record: recorder),
            liveSessionIsRunning: false
        )
        #expect(await recorder.calls().isEmpty)
        #expect(active.viewModel.presentedError == "请先停止当前会议。")

        let unknown = try RetranscriptionFixture(sourceLanguage: "fr", targetLanguage: "en")
        defer { unknown.remove() }
        await unknown.viewModel.retranscribeRetainedRecording(
            for: unknown.summary,
            using: RetranscriptionImporterFake(record: recorder),
            liveSessionIsRunning: false
        )
        #expect(await recorder.calls().isEmpty)
        #expect(
            unknown.viewModel.presentedError
                == "无法确定这份录音的语言方向。现有资料没有受到影响。"
        )
    }

    @Test func concurrentRequestDoesNotStartASecondImportOrDeleteSource() async throws {
        let fixture = try RetranscriptionFixture()
        defer { fixture.remove() }
        await fixture.viewModel.load()
        let recorder = RetranscriptionCallRecorder()
        let gate = RetranscriptionGate()
        let importer = RetranscriptionImporterFake { url, mode, title in
            await recorder.record(url: url, mode: mode, title: title)
            await gate.wait()
        }
        let first = Task {
            await fixture.viewModel.retranscribeRetainedRecording(
                for: fixture.summary,
                using: importer,
                liveSessionIsRunning: false
            )
        }
        try await waitUntil { await recorder.calls().count == 1 }

        await fixture.viewModel.retranscribeRetainedRecording(
            for: fixture.summary,
            using: importer,
            liveSessionIsRunning: false
        )
        await fixture.viewModel.deleteSelected()

        #expect(await recorder.calls().count == 1)
        #expect(await fixture.store.deletedIDs().isEmpty)
        #expect(fixture.viewModel.presentedError == "请等待当前音频处理完成。")
        await gate.release()
        await first.value
        #expect(!fixture.viewModel.isImporting)
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw RetranscriptionTestError.timedOut
    }
}
