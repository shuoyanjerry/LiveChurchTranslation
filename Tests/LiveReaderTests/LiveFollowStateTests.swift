import LiveReader
import Testing

@Suite struct LiveFollowStateTests {
    @Test func newTranscriptDoesNotInterruptReadingHistory() {
        var state = LiveFollowState()

        state.userDidScroll(isAtLiveEdge: false)

        #expect(state.isFollowingLive == false)
        #expect(state.contentDidAppend() == false)
        #expect(state.unseenEntryCount == 1)
    }

    @Test func jumpToLiveRestoresFollowing() {
        var state = LiveFollowState(isFollowingLive: false)

        let shouldScroll = state.jumpToLive()

        #expect(shouldScroll)
        #expect(state.isFollowingLive)
        #expect(state.unseenEntryCount == 0)
        let followsAppend = state.contentDidAppend()
        #expect(followsAppend)
    }

    @Test func newTranscriptFollowsWhenReaderIsAtLiveEdge() {
        var state = LiveFollowState(isFollowingLive: false)

        state.userDidScroll(isAtLiveEdge: true)

        #expect(state.isFollowingLive)
        let followsAppend = state.contentDidAppend()
        #expect(followsAppend)
    }

    @Test func contentGrowthDoesNotChangeTheUserViewportIntent() {
        var state = LiveFollowState(isFollowingLive: false)

        let firstAppend = state.contentDidAppend()
        let secondAppend = state.contentDidAppend()

        #expect(!firstAppend)
        #expect(!secondAppend)
        #expect(!state.isFollowingLive)
        #expect(state.unseenEntryCount == 2)
    }
}
