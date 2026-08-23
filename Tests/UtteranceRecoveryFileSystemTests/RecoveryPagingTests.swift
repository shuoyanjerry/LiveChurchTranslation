import Foundation
import Testing
import UtteranceRecoveryAPI
import UtteranceRecoveryFileSystem

@Suite struct RecoveryPagingTests {
    @Test func largeBacklogNeverExceedsRequestedDecodedPageBound() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        let sampleCount = 64
        let recordCount = 128
        let pageSize = 7
        for sequence in 0..<recordCount {
            _ = try await store.stage(
                fixture.segment(
                    sequence: UInt64(sequence),
                    samples: Array(repeating: 0.25, count: sampleCount)
                ),
                for: fixture.sessionID
            )
        }

        let pages = try await store.recoverAllPendingPages(
            maximumRecordsPerPage: pageSize
        )
        var recoveredSequences: [UInt64] = []
        var maximumDecodedSamples = 0
        var pageCount = 0
        for try await page in pages {
            pageCount += 1
            #expect(page.pending.count + page.quarantined.count <= pageSize)
            let decodedSamples = page.pending.reduce(0) { $0 + $1.segment.samples.count }
            maximumDecodedSamples = max(maximumDecodedSamples, decodedSamples)
            recoveredSequences.append(contentsOf: page.pending.map(\.id.sequenceNumber))
        }

        #expect(pageCount == 19)
        #expect(maximumDecodedSamples <= pageSize * sampleCount)
        #expect(recoveredSequences == (0..<recordCount).map(UInt64.init))
    }

    @Test func audioIsDecodedOnlyWhenItsPageIsRequested() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()
        _ = try await store.stage(fixture.segment(sequence: 1), for: fixture.sessionID)
        _ = try await store.stage(fixture.segment(sequence: 2), for: fixture.sessionID)
        _ = try await store.stage(fixture.segment(sequence: 3), for: fixture.sessionID)
        let firstAudio = try fixture.pendingRecordDirectory(sequence: 1)
            .appending(path: "audio.wav")
        let secondAudio = try fixture.pendingRecordDirectory(sequence: 2)
            .appending(path: "audio.wav")

        let recoveryStore: any UtteranceRecoveryStore = store
        let pages = try await recoveryStore.recoverAllPendingPages(maximumRecordsPerPage: 1)
        var iterator = pages.makeAsyncIterator()
        try Data("late-corruption-one".utf8).write(to: firstAudio, options: .atomic)
        let firstValue = try await iterator.next()
        let first = try #require(firstValue)
        #expect(first.pending.isEmpty)
        #expect(first.quarantined.map(\.reason) == [.malformedAudio])

        try Data("late-corruption-two".utf8).write(to: secondAudio, options: .atomic)
        let secondValue = try await iterator.next()
        let second = try #require(secondValue)
        #expect(second.pending.isEmpty)
        #expect(second.quarantined.map(\.reason) == [.malformedAudio])
        let thirdValue = try await iterator.next()
        let third = try #require(thirdValue)
        #expect(third.pending.map(\.id.sequenceNumber) == [3])
        #expect(third.quarantined.isEmpty)
        let end = try await iterator.next()
        #expect(end == nil)
    }

    @Test func pagesKeepSessionsContiguousAndSequencesStable() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let earlySession = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let lateSession = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let earlyStore = try FileUtteranceRecoveryStore(
            root: fixture.root,
            now: { fixture.stagedAt }
        )
        _ = try await earlyStore.stage(fixture.segment(sequence: 9), for: earlySession)
        _ = try await earlyStore.stage(fixture.segment(sequence: 2), for: earlySession)
        let lateStore = try FileUtteranceRecoveryStore(
            root: fixture.root,
            now: { fixture.stagedAt.addingTimeInterval(10) }
        )
        _ = try await lateStore.stage(fixture.segment(sequence: 1), for: lateSession)

        let pages = try await lateStore.recoverAllPendingPages(maximumRecordsPerPage: 2)
        var identities: [(UUID, UInt64)] = []
        for try await page in pages {
            identities += page.pending.map { ($0.id.sessionID, $0.id.sequenceNumber) }
        }

        #expect(identities.map(\.0) == [earlySession, earlySession, lateSession])
        #expect(identities.map(\.1) == [2, 9, 1])
    }

    @Test func rejectsNonpositivePageSize() async throws {
        let fixture = try RecoveryTestFixture()
        defer { fixture.removeRoot() }
        let store = try fixture.store()

        await #expect(
            throws: UtteranceRecoveryError.invalidConfiguration("maximumRecordsPerPage")
        ) {
            try await store.recoverAllPendingPages(maximumRecordsPerPage: 0)
        }
    }
}
