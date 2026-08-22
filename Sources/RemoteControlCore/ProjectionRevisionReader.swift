import RemoteControlAPI
import RemoteSharingAPI

public struct ProjectionRevisionReader: RemoteRevisionReading {
    private let projection: any RemoteProjectionProviding

    public init(projection: any RemoteProjectionProviding) {
        self.projection = projection
    }

    public func currentRemoteRevision() async -> UInt64 {
        await projection.snapshot().revision
    }
}
