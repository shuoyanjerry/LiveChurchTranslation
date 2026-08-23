import Testing
import VADAPI
@testable import VADCore

@MainActor
@Suite struct CandidatePauseLifecycleTests {
    @Test func hardCapContinuationUsesItsNewSequence() async throws {
        let detector = try CandidatePauseTestSupport.detector(
            preferredMaximum: .milliseconds(500),
            maximumGrace: .zero
        )
        let speech = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0.1, milliseconds: 520, timestamp: .zero
        )
        let pause = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0, milliseconds: 260, timestamp: .milliseconds(520)
        )

        #expect(VADTestSupport.startedEvents(in: speech.voiceEvents).map(\.sequenceNumber) == [1, 2])
        let hard = try #require(VADTestSupport.endedSegments(in: speech.voiceEvents).first)
        #expect(hard.sequenceNumber == 1)
        #expect(hard.endReason == .maximumDuration)
        let reached = try #require(
            CandidatePauseTestSupport.reached(in: pause.pauseEvents).first
        )
        #expect(reached.episode.sequenceNumber == 2)
        #expect(reached.candidateEnd.sourceSample == 12_320)
    }

    @Test func productionEventsMatchShadowObservationPath() async throws {
        let production = try CandidatePauseTestSupport.detector()
        let shadow = try CandidatePauseTestSupport.detector()
        let frames = [
            CandidatePauseParityFrame(amplitude: 0, milliseconds: 100, timestamp: .zero),
            CandidatePauseParityFrame(
                amplitude: 0.1, milliseconds: 400, timestamp: .milliseconds(100)
            ),
            CandidatePauseParityFrame(
                amplitude: 0, milliseconds: 700, timestamp: .milliseconds(500)
            ),
            CandidatePauseParityFrame(
                amplitude: 0.1, milliseconds: 300, timestamp: .milliseconds(1_200)
            ),
        ]
        var productionEvents: [VoiceActivityEvent] = []
        var shadowEvents: [VoiceActivityEvent] = []
        for value in frames {
            let frame = VADTestSupport.frame(
                amplitude: value.amplitude,
                milliseconds: value.milliseconds,
                timestamp: value.timestamp
            )
            productionEvents += try await production.process(frame)
            shadowEvents += try await shadow.processWithShadowEvidence(frame).voiceEvents
        }
        productionEvents += await production.flush()
        shadowEvents += await shadow.flushWithShadowEvidence().voiceEvents

        #expect(
            CandidatePauseTestSupport.voiceSignature(productionEvents)
                == CandidatePauseTestSupport.voiceSignature(shadowEvents)
        )
    }

    @Test func unconfirmedSpeechCannotPublishPauseEvidence() async throws {
        let detector = try CandidatePauseTestSupport.detector(
            minimumVoiced: .milliseconds(400)
        )
        let speech = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0.1, milliseconds: 100, timestamp: .zero
        )
        let pause = try await CandidatePauseTestSupport.observe(
            detector, amplitude: 0, milliseconds: 420, timestamp: .milliseconds(100)
        )
        let flushed = await detector.flushWithShadowEvidence()

        #expect(speech.voiceEvents.isEmpty)
        #expect(pause.pauseEvents.isEmpty)
        #expect(flushed.voiceEvents.isEmpty)
        #expect(flushed.pauseEvents.isEmpty)
    }

    @Test func rollingPreRollStorageAndAbsoluteOriginStayBounded() {
        let capacity = 640
        let windowSize = 320
        let windowCount = 10_000
        var buffer = RollingAudioBuffer(capacity: capacity, sampleRate: 16_000)
        for index in 0..<windowCount {
            buffer.append(
                Array(repeating: Float(index % 2), count: windowSize),
                at: .milliseconds(index * 20),
                sourceSampleStart: Int64(index * windowSize)
            )
        }

        #expect(buffer.samples.count == capacity)
        #expect(buffer.samples.capacity <= capacity * 4)
        #expect(buffer.startedAtSourceSample == Int64(windowCount * windowSize - capacity))
        #expect(buffer.startedAt == .milliseconds((windowCount - 2) * 20))
    }
}

private struct CandidatePauseParityFrame {
    let amplitude: Float
    let milliseconds: Int
    let timestamp: Duration
}
