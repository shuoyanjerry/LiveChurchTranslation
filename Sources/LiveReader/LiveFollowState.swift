/// Value state that decides whether the reader should follow new transcript entries.
public struct LiveFollowState: Equatable, Sendable {
    /// Whether the reader is currently following the live edge.
    public private(set) var isFollowingLive: Bool
    public private(set) var unseenEntryCount: Int

    public init(isFollowingLive: Bool = true, unseenEntryCount: Int = 0) {
        self.isFollowingLive = isFollowingLive
        self.unseenEntryCount = max(0, unseenEntryCount)
    }

    /// Records the latest user-controlled viewport position.
    public mutating func userDidScroll(isAtLiveEdge: Bool) {
        isFollowingLive = isAtLiveEdge
        if isAtLiveEdge { unseenEntryCount = 0 }
    }

    /// Records appended content without confusing it with a user scroll.
    public mutating func contentDidAppend() -> Bool {
        guard !isFollowingLive else { return true }
        unseenEntryCount += 1
        return false
    }

    /// Restores live following and requests one immediate scroll to the live edge.
    @discardableResult
    public mutating func jumpToLive() -> Bool {
        isFollowingLive = true
        unseenEntryCount = 0
        return true
    }
}
