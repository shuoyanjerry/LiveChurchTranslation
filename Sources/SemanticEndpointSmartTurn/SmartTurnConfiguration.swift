import SemanticEndpointAPI

public struct SmartTurnConfiguration: Equatable, Sendable {
    public static let `default` = SmartTurnConfiguration(validatedThreshold: 0.5)

    public let completionThreshold: Float

    public init(completionThreshold: Float) throws {
        guard completionThreshold.isFinite, (0...1).contains(completionThreshold) else {
            throw SemanticEndpointError.invalidThreshold(completionThreshold)
        }
        self.completionThreshold = completionThreshold
    }

    private init(validatedThreshold: Float) {
        completionThreshold = validatedThreshold
    }
}

public struct SmartTurnModelIdentity: Equatable, Sendable {
    public static let version3Point2CPU = SmartTurnModelIdentity(
        huggingFaceRevision: "f766f81d3cfdf7737ac64aad813d91bbfd56bf93",
        sha256: "2bb026316b14a660486a75b1733cd3fbab8c2fd0314dc9af7be49f8cca967e4f"
    )

    public let huggingFaceRevision: String
    public let sha256: String

    public init(huggingFaceRevision: String, sha256: String) {
        self.huggingFaceRevision = huggingFaceRevision
        self.sha256 = sha256
    }
}
