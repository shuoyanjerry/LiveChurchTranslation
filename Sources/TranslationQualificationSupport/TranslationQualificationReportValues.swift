import Foundation

public struct TranslationQualificationProvider: Codable, Equatable, Sendable {
    public let identifier: String
    public let modelRevision: String
    public let modelSHA256: String
    public let runtimeRevision: String
    public let runtimeSHA256: String
    public let settings: [String: String]

    public init(
        identifier: String,
        modelRevision: String,
        modelSHA256: String,
        runtimeRevision: String,
        runtimeSHA256: String,
        settings: [String: String]
    ) {
        self.identifier = identifier
        self.modelRevision = modelRevision
        self.modelSHA256 = modelSHA256
        self.runtimeRevision = runtimeRevision
        self.runtimeSHA256 = runtimeSHA256
        self.settings = settings
    }
}

public struct TranslationQualificationEnvironment: Codable, Equatable, Sendable {
    public let hardware: String
    public let operatingSystem: String
    public let repositoryRevision: String
    public let backgroundLoad: String

    public init(
        hardware: String,
        operatingSystem: String,
        repositoryRevision: String,
        backgroundLoad: String
    ) {
        self.hardware = hardware
        self.operatingSystem = operatingSystem
        self.repositoryRevision = repositoryRevision
        self.backgroundLoad = backgroundLoad
    }
}

public enum TranslationQualificationAttemptStatus: String, Codable, Equatable, Sendable {
    case success
    case failure
}

public enum TranslationQualificationCheckStatus: String, Codable, Equatable, Sendable {
    case pass
    case fail
    case notApplicable
    case humanReviewRequired
}

public struct TranslationQualificationCheck: Codable, Equatable, Sendable {
    public let kind: String
    public let status: TranslationQualificationCheckStatus
    public let expected: [String]
    public let observed: [String]

    public init(
        kind: String,
        status: TranslationQualificationCheckStatus,
        expected: [String] = [],
        observed: [String] = []
    ) {
        self.kind = kind
        self.status = status
        self.expected = expected
        self.observed = observed
    }
}

public struct TranslationQualificationTermResult: Codable, Equatable, Sendable {
    public let source: String
    public let preferredTarget: String
    public let acceptedTargets: [String]
    public let required: Bool
    public let status: TranslationQualificationCheckStatus

    public init(
        source: String,
        preferredTarget: String,
        acceptedTargets: [String],
        required: Bool,
        status: TranslationQualificationCheckStatus
    ) {
        self.source = source
        self.preferredTarget = preferredTarget
        self.acceptedTargets = acceptedTargets
        self.required = required
        self.status = status
    }
}

public struct TranslationQualificationPronounResult: Codable, Equatable, Sendable {
    public let occurrenceID: String
    public let expectedGuidance: TranslationExpectedPronounGuidance
    public let actualGuidance: String
    public let guidanceStatus: TranslationQualificationCheckStatus
    public let englishToken: String?
    public let englishClass: String
    public let englishPolicyStatus: TranslationQualificationCheckStatus

    public init(
        occurrenceID: String,
        expectedGuidance: TranslationExpectedPronounGuidance,
        actualGuidance: String,
        guidanceStatus: TranslationQualificationCheckStatus,
        englishToken: String?,
        englishClass: String,
        englishPolicyStatus: TranslationQualificationCheckStatus
    ) {
        self.occurrenceID = occurrenceID
        self.expectedGuidance = expectedGuidance
        self.actualGuidance = actualGuidance
        self.guidanceStatus = guidanceStatus
        self.englishToken = englishToken
        self.englishClass = englishClass
        self.englishPolicyStatus = englishPolicyStatus
    }
}
