import Foundation

/// Immutable provider identity recorded by Report V3.
public struct ASRQualificationProviderMetadataV3: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let lane: String
    public let modelRevision: String
    public let runtimeRevision: String
    public let settings: [String: String]

    public init(
        name: String,
        lane: String = "productionAdapter",
        modelRevision: String,
        runtimeRevision: String,
        settings: [String: String] = [:]
    ) {
        self.name = name
        self.lane = lane
        self.modelRevision = modelRevision
        self.runtimeRevision = runtimeRevision
        self.settings = settings
    }
}

/// Host and repository identity recorded by Report V3.
public struct ASRQualificationEnvironmentV3: Codable, Equatable, Hashable, Sendable {
    public let os: String
    public let hardware: String
    public let architecture: String
    public let buildConfiguration: String
    public let repositoryRevision: String
    public let repositoryDirty: Bool
    public let backgroundLoadNote: String

    public init(
        os: String,
        hardware: String,
        architecture: String,
        buildConfiguration: String,
        repositoryRevision: String,
        repositoryDirty: Bool,
        backgroundLoadNote: String
    ) {
        self.os = os
        self.hardware = hardware
        self.architecture = architecture
        self.buildConfiguration = buildConfiguration
        self.repositoryRevision = repositoryRevision
        self.repositoryDirty = repositoryDirty
        self.backgroundLoadNote = backgroundLoadNote
    }
}

public enum ASRQualificationAttemptStatusV3: String, Codable, Equatable, Hashable, Sendable {
    case success
    case failure
}

/// One provider invocation for one frozen manifest segment.
public struct ASRQualificationAttemptV3: Codable, Equatable, Hashable, Sendable {
    public let sequence: Int
    public let inputSampleCount: Int
    public let pcmSHA256: String
    public let elapsedSeconds: Double
    public let status: ASRQualificationAttemptStatusV3
    public let hypothesis: String?
    public let failureCode: String?

    public init(
        sequence: Int,
        inputSampleCount: Int,
        pcmSHA256: String,
        elapsedSeconds: Double,
        status: ASRQualificationAttemptStatusV3,
        hypothesis: String? = nil,
        failureCode: String? = nil
    ) {
        self.sequence = sequence
        self.inputSampleCount = inputSampleCount
        self.pcmSHA256 = pcmSHA256
        self.elapsedSeconds = elapsedSeconds
        self.status = status
        self.hypothesis = hypothesis
        self.failureCode = failureCode
    }
}

/// Provider-neutral observations for one manifest clip.
public struct ASRQualificationClipEvaluationInputV3: Codable, Equatable, Sendable {
    public let id: String
    public let referenceText: String
    public let sourceAudioSeconds: Double
    public let segments: [ASRQualificationSegmentV2]
    public let attempts: [ASRQualificationAttemptV3]

    public init(
        id: String,
        referenceText: String,
        sourceAudioSeconds: Double,
        segments: [ASRQualificationSegmentV2],
        attempts: [ASRQualificationAttemptV3]
    ) {
        self.id = id
        self.referenceText = referenceText
        self.sourceAudioSeconds = sourceAudioSeconds
        self.segments = segments
        self.attempts = attempts
    }
}
