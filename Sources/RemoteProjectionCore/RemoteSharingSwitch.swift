import RemoteSharingAPI

public actor RemoteSharingSwitch: RemoteSharingControlling {
    private var enabled = false

    public init() {}

    public func isEnabled() -> Bool { enabled }

    public func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
    }
}
