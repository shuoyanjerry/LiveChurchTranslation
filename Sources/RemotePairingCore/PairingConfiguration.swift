import Foundation

public struct PairingConfiguration: Equatable, Sendable {
    public let invitationTTL: TimeInterval
    public let grantTTL: TimeInterval
    public let maximumActiveGrants: Int
    public let maximumAuditRecords: Int

    public init(
        invitationTTL: TimeInterval = 120,
        grantTTL: TimeInterval = 8 * 60 * 60,
        maximumActiveGrants: Int = 32,
        maximumAuditRecords: Int = 512
    ) {
        self.invitationTTL = min(max(invitationTTL, 15), 300)
        self.grantTTL = min(max(grantTTL, 60), 24 * 60 * 60)
        self.maximumActiveGrants = min(max(maximumActiveGrants, 1), 128)
        self.maximumAuditRecords = min(max(maximumAuditRecords, 16), 4_096)
    }
}
