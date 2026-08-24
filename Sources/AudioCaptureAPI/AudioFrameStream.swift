public enum AudioFrameStream {
    public typealias Stream = AsyncThrowingStream<AudioFrame, any Error>
    public static let defaultBacklogFrameLimit = 4_096

    public static func makeBounded(
        frameLimit: Int = defaultBacklogFrameLimit
    ) -> (
        stream: Stream,
        continuation: Stream.Continuation
    ) {
        Stream.makeStream(bufferingPolicy: .bufferingOldest(max(1, frameLimit)))
    }
}
