import Foundation
@testable import SessionManagement
import Testing
import UtteranceRecoveryAPI
import VADAPI

@Suite struct PendingUtteranceQueueTests {
    @Test func ringBufferPreservesFIFOOrderAcrossTenThousandWraps() throws {
        var queue = PendingUtteranceQueue(
            policy: UtteranceQueuePolicy(maximumRecords: 8, maximumSamples: 80)
        )
        var expectedSequence: UInt64 = 0

        for sequence in 0..<10_000 {
            if queue.count == queue.policy.maximumRecords {
                let dequeued = queue.dequeue()
                let record = try #require(dequeued)
                #expect(record.id.sequenceNumber == expectedSequence)
                expectedSequence += 1
            }
            #expect(queue.enqueue(record(sequence: UInt64(sequence))) == .admitted)
        }
        while let record = queue.dequeue() {
            #expect(record.id.sequenceNumber == expectedSequence)
            expectedSequence += 1
        }

        #expect(expectedSequence == 10_000)
        #expect(queue.count == 0)
        #expect(queue.sampleCount == 0)
    }

    @Test func sampleBudgetRejectsWithoutMutatingQueuedRecords() throws {
        var queue = PendingUtteranceQueue(
            policy: UtteranceQueuePolicy(maximumRecords: 4, maximumSamples: 10)
        )

        #expect(queue.enqueue(record(sequence: 1, samples: 6)) == .admitted)
        #expect(queue.enqueue(record(sequence: 2, samples: 5)) == .rejected(.sampleCount))
        #expect(queue.count == 1)
        #expect(queue.sampleCount == 6)
        let dequeued = queue.dequeue()
        #expect(try #require(dequeued).id.sequenceNumber == 1)
        #expect(queue.enqueue(record(sequence: 2, samples: 5)) == .admitted)
    }

    @Test func recordBudgetRejectsWithoutReplacingOldestRecord() throws {
        var queue = PendingUtteranceQueue(
            policy: UtteranceQueuePolicy(maximumRecords: 2, maximumSamples: 100)
        )

        #expect(queue.enqueue(record(sequence: 1)) == .admitted)
        #expect(queue.enqueue(record(sequence: 2)) == .admitted)
        #expect(queue.enqueue(record(sequence: 3)) == .rejected(.recordCount))
        let first = queue.dequeue()
        let second = queue.dequeue()
        #expect(try #require(first).id.sequenceNumber == 1)
        #expect(try #require(second).id.sequenceNumber == 2)
    }

    private func record(
        sequence: UInt64,
        samples: Int = 1
    ) -> PendingUtteranceRecord {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let segmentID = UUID(
            uuidString: String(format: "00000000-0000-0000-0000-%012llu", sequence + 1)
        )!
        let segment = SpeechSegment(
            id: segmentID,
            sequenceNumber: sequence,
            samples: Array(repeating: 0.25, count: samples),
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .milliseconds(20),
            endReason: .trailingSilence
        )
        return PendingUtteranceRecord(
            id: PendingUtteranceID(
                sessionID: sessionID,
                segmentID: segmentID,
                sequenceNumber: sequence
            ),
            segment: segment,
            stagedAt: Date(timeIntervalSince1970: TimeInterval(sequence))
        )
    }
}
