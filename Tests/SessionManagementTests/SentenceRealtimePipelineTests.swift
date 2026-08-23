import Foundation
@testable import SessionManagement
import Testing

@Suite struct SentenceRealtimePipelineTests {
    @Test func oneAcousticSegmentPublishesEachSentenceImmediatelyInOrder() async throws {
        let clock = ScriptedSentenceVisibilityClock(
            values: [.zero, .seconds(1), .seconds(2), .seconds(2.5)]
        )
        let harness = SessionTestHarness(
            recognizedText: "Grace saves us. Christ is Lord. We pray.",
            translationMode: .englishToSimplifiedChinese,
            sentenceVisibilityClock: clock
        )

        let events = try await harness.run()

        let entries = events.appendedEntries
        #expect(
            entries.map(\.sourceText) == [
                "Grace saves us.", "Christ is Lord.", "We pray.",
            ])
        #expect(entries.map(\.sequence) == [1, 2, 3])
        #expect(Set(entries.map(\.id)).count == 3)
        #expect(entries.compactMap(\.sourceSegmentSequence) == [1, 1, 1])
        let requests = await harness.translator.receivedRequests()
        #expect(requests.map(\.sourceText) == entries.map(\.sourceText))
        #expect(requests[0].context.isEmpty)
        #expect(requests[1].context.map(\.sourceText) == ["Grace saves us."])
        #expect(
            requests[2].context.map(\.sourceText) == [
                "Grace saves us.", "Christ is Lord.",
            ])
        try await expectPerSentenceVisibility(harness)
    }

    @Test func sentenceTailToVisibleUsesInjectedMonotonicClock() async throws {
        let harness = SessionTestHarness(
            sentenceVisibilityClock: ScriptedSentenceVisibilityClock(
                values: [.seconds(10), .milliseconds(12_400)]
            )
        )

        let events = try await harness.run()

        #expect(events.appendedEntries.count == 1)
        try await waitUntil {
            await harness.diagnostics.recordedEvents().contains {
                $0.component == "SentenceVisibility"
            }
        }
        let metric = try #require(
            await harness.diagnostics.recordedEvents().first {
                $0.component == "SentenceVisibility"
            }
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
        try await waitUntil {
            await harness.diagnostics.recordedEvents().filter {
                $0.component == "SentenceVisibility"
            }.count == 2
        }

        let metrics = await harness.diagnostics.recordedEvents().filter {
            $0.component == "SentenceVisibility"
        }
        #expect(metrics.map { $0.measurements["tail_to_visible_ms"] } == [1_000, 1_000])
    }

}

private func expectPerSentenceVisibility(_ harness: SessionTestHarness) async throws {
    try await waitUntil {
        await harness.diagnostics.recordedEvents().filter {
            $0.component == "SentenceVisibility"
        }.count == 3
    }
    let visibility = await harness.diagnostics.recordedEvents().filter {
        $0.component == "SentenceVisibility"
    }.sorted {
        $0.measurements["presentation_sequence", default: 0]
            < $1.measurements["presentation_sequence", default: 0]
    }
    #expect(visibility.map { $0.measurements["presentation_sequence"] } == [1, 2, 3])
    let observedTimes = visibility.map {
        $0.measurements["sentence_tail_audio_ms", default: 0]
            + $0.measurements["tail_to_visible_ms", default: 0]
    }
    #expect(
        zip(observedTimes, [1_020.0, 2_020.0, 2_520.0]).allSatisfy {
            abs($0 - $1) < 0.001
        })
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
