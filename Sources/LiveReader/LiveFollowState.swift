/// Value state that decides whether the reader should follow new transcript entries.
public struct LiveFollowState: Equatable, Sendable {
    /// Whether the reader is currently following the live edge.
    public private(set) var isFollowingLive: Bool

    public init(isFollowingLive: Bool = true) {
        self.isFollowingLive = isFollowingLive
    }

    /// Records the latest user-controlled viewport position.
    public mutating func userDidScroll(isAtLiveEdge: Bool) {
        isFollowingLive = isAtLiveEdge
    }

    /// Returns whether a newly appended transcript entry should be revealed.
    public func shouldRevealNewTranscript() -> Bool {
        isFollowingLive
    }

    /// Restores live following and requests one immediate scroll to the live edge.
    @discardableResult
    public mutating func jumpToLive() -> Bool {
        isFollowingLive = true
        return true
    }
}
