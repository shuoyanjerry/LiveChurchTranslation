import LiveReader
import Testing

@Suite struct LiveFollowStateTests {
    @Test func newTranscriptDoesNotInterruptReadingHistory() {
        var state = LiveFollowState()

        state.userDidScroll(isAtLiveEdge: false)

        #expect(state.isFollowingLive == false)
        #expect(state.shouldRevealNewTranscript() == false)
    }

    @Test func jumpToLiveRestoresFollowing() {
        var state = LiveFollowState(isFollowingLive: false)

        let shouldScroll = state.jumpToLive()

        #expect(shouldScroll)
        #expect(state.isFollowingLive)
        #expect(state.shouldRevealNewTranscript())
    }

    @Test func newTranscriptFollowsWhenReaderIsAtLiveEdge() {
        var state = LiveFollowState(isFollowingLive: false)

        state.userDidScroll(isAtLiveEdge: true)

        #expect(state.isFollowingLive)
        #expect(state.shouldRevealNewTranscript())
    }
}
