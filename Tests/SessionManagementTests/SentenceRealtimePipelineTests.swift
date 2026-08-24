import AudioCaptureAPI
import DiagnosticsAPI
import Foundation
@testable import SessionManagement
import Testing

@Suite struct SentenceRealtimePipelineTests {
    @Test func oneAcousticSegmentTranslatesAndPublishesOneCompleteBlock() async throws {
        let source = "Grace saves us. Christ is Lord. We pray."
        let target = "恩典拯救我们。基督是主。我们祷告。"
        let harness = SessionTestHarness(
            recognizedText: source,
            translationOutputs: [target],
            translationMode: .englishToSimplifiedChinese,
            sentenceVisibilityClock: ScriptedSentenceVisibilityClock(values: [.zero, .seconds(1)])
        )

        let events = try await harness.run()

        let entries = events.appendedEntries
        #expect(entries.map(\.sourceText) == [source])
        #expect(entries.map(\.targetText) == [target])
        #expect(entries.map(\.sequence) == [1])
        #expect(entries.compactMap(\.sourceSegmentSequence) == [1])
        let asrRequest = try #require(await harness.asr.receivedRequests().first)
        #expect(entries.first?.id == asrRequest.segment.id)
        #expect(entries.first?.rawSourceText == source)
        let requests = await harness.translator.receivedRequests()
        #expect(requests.map(\.sourceText) == [source])
        #expect(requests[0].context.isEmpty)
        let persisted = await harness.store.persistedEntries()
        #expect(persisted.map(\.sourceText) == [source])
        #expect(persisted.map(\.targetText) == [target])
        let visibility = try #require(
            try await visibilityEvents(harness, expectedCount: 1).first
        )
        #expect(visibility.measurements["presentation_sequence"] == 1)
        #expect(visibility.measurements["sentence_tail_audio_ms"] == 20)
        #expect(visibility.measurements["tail_to_visible_ms"] == 1_000)
    }

    @Test func contextCarriesEachPriorSegmentExactlyOnce() async throws {
        let first = "Grace saves us. Christ is Lord."
        let second = "We pray together. God hears us."
        let frames = (0..<2).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
        let harness = SessionTestHarness(
            recognizedTexts: [first, second],
            emitsEveryFrame: true,
            translationMode: .englishToSimplifiedChinese,
            audioFrames: frames
        )

        let events = try await harness.run()

        #expect(events.appendedEntries.map(\.sourceText) == [first, second])
        let requests = await harness.translator.receivedRequests()
        #expect(requests.map(\.sourceText) == [first, second])
        #expect(requests[0].context.isEmpty)
        #expect(requests[1].context.map(\.sourceText) == [first])
    }
}

extension SentenceRealtimePipelineTests {
    @Test func sentenceTailToVisibleUsesInjectedMonotonicClock() async throws {
        let harness = SessionTestHarness(
            sentenceVisibilityClock: ScriptedSentenceVisibilityClock(
                values: [.seconds(10), .milliseconds(12_400)]
            )
        )

        let events = try await harness.run()

        #expect(events.appendedEntries.count == 1)
        let metric = try #require(
            try await visibilityEvents(harness, expectedCount: 1).first
        )
        #expect(metric.measurements["tail_to_visible_ms"] == 2_400)
        #expect(metric.measurements["budget_ms"] == 3_000)
        #expect(metric.measurements["clock_mapping_valid"] == 1)
        #expect(metric.measurements["sla_met"] == 1)
        #expect(metric.severity == .info)
    }

    @Test func invalidClockMappingIsReportedWithoutClamping() {
        let metric = SentenceRealtimePolicy.diagnostic(
            sourceSegmentSequence: 1,
            presentationSequence: 1,
            sentenceTail: .zero,
            tailObservedAt: .seconds(2),
            visibleAt: .seconds(1)
        )

        #expect(metric.measurements["tail_to_visible_ms"] == -1_000)
        #expect(metric.measurements["clock_mapping_valid"] == 0)
        #expect(metric.measurements["sla_met"] == 0)
        #expect(metric.severity == .warning)
    }

    @Test func negativeMappedTailIsReportedEvenWhenLatencyIsPositive() {
        let metric = SentenceRealtimePolicy.diagnostic(
            sourceSegmentSequence: 1,
            presentationSequence: 1,
            sentenceTail: .zero,
            tailObservedAt: .seconds(-2),
            visibleAt: .seconds(1)
        )

        #expect(metric.measurements["tail_to_visible_ms"] == 3_000)
        #expect(metric.measurements["clock_mapping_valid"] == 0)
        #expect(metric.measurements["sla_met"] == 0)
        #expect(metric.severity == .warning)
    }

    @Test func importedAudioDoesNotPublishRealtimeSLA() async throws {
        let harness = SessionTestHarness(
            sessionKind: .importedAudio,
            sentenceVisibilityClock: ScriptedSentenceVisibilityClock(values: [.zero])
        )

        _ = try await harness.run()

        #expect(
            await harness.diagnostics.recordedEvents().allSatisfy {
                $0.component != "SentenceVisibility"
            }
        )
    }

    @Test func aNewCaptureReanchorsTheAudioTimeline() async throws {
        let harness = SessionTestHarness(
            sentenceVisibilityClock: ScriptedSentenceVisibilityClock(
                values: [.zero, .seconds(1), .seconds(10), .seconds(11)]
            )
        )

        _ = try await harness.run()
        _ = try await harness.run()
        let metrics = try await visibilityEvents(harness, expectedCount: 2)
        #expect(metrics.map { $0.measurements["tail_to_visible_ms"] } == [1_000, 1_000])
    }
}

private func visibilityEvents(
    _ harness: SessionTestHarness,
    expectedCount: Int
) async throws -> [DiagnosticEvent] {
    try await waitUntil {
        await harness.diagnostics.recordedEvents().filter {
            $0.component == "SentenceVisibility"
        }.count == expectedCount
    }
    return await harness.diagnostics.recordedEvents().filter {
        $0.component == "SentenceVisibility"
    }
}

private final class ScriptedSentenceVisibilityClock: SentenceVisibilityClock, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Duration]

    init(values: [Duration]) {
        precondition(!values.isEmpty)
        self.values = values
    }

    func now() -> Duration {
        lock.withLock {
            precondition(!values.isEmpty)
            return values.removeFirst()
        }
    }
}
