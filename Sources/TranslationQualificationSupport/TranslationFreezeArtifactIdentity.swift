public struct TranslationFreezeArtifactIdentity: Equatable, Sendable {
    public let reportFilename: String
    public let reportSHA256: String
    public let postflightFilename: String
    public let postflightSHA256: String
    public let reviewPacketFilename: String
    public let reviewPacketSHA256: String

    public init(
        reportFilename: String,
        reportSHA256: String,
        postflightFilename: String,
        postflightSHA256: String,
        reviewPacketFilename: String,
        reviewPacketSHA256: String
    ) {
        self.reportFilename = reportFilename
        self.reportSHA256 = reportSHA256
        self.postflightFilename = postflightFilename
        self.postflightSHA256 = postflightSHA256
        self.reviewPacketFilename = reviewPacketFilename
        self.reviewPacketSHA256 = reviewPacketSHA256
    }
}
