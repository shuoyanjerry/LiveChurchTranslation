import Foundation
import ScriptureAPI
import ScriptureQualificationSupport

struct ScriptureModelQualificationReport: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let corpusID: String
    let manifestSHA256: String
    let generatedAt: Date
    let policy: ScriptureQualificationExecutionPolicy
    let gatePolicyRevision: String
    let qualified: Bool
    let providers: [ScriptureQualificationProviderIdentity]
    let declarations: [ScriptureDeclarationIdentity]
    let items: [ScriptureSourceIdentityEvidence]
    let pairs: [ScriptureQualificationPairIdentity]
    let aggregates: [ScriptureQualificationAggregate]
    let failures: [ScriptureQualificationFailureIdentity]
    let gates: [ScriptureQualificationLaneGate]

    var totalFailures: Int {
        aggregates.reduce(0) { $0 + $1.failureCount }
    }
}

struct ScriptureQualificationExecutionPolicy: Codable, Equatable, Sendable {
    let phase: ScriptureQualificationPhase
    let aggregateOnly: Bool
    let modelWeightsModified: Bool
    let modelTrainingPerformed: Bool
    let developmentMayGuideNonWeightAdjustment: Bool
    let sealedQualificationMayGuideAdjustment: Bool

    static func fixed(phase: ScriptureQualificationPhase) -> Self {
        Self(
            phase: phase,
            aggregateOnly: true,
            modelWeightsModified: false,
            modelTrainingPerformed: false,
            developmentMayGuideNonWeightAdjustment: phase == .development,
            sealedQualificationMayGuideAdjustment: false
        )
    }
}

struct ScriptureQualificationProviderIdentity: Codable, Equatable, Sendable {
    let identifier: String
    let modelRevision: String
    let modelSHA256: String
    let runtimeRevision: String
    let runtimeSHA256: String?
    let runtimeBundleSHA256: String?
}

struct ScriptureDeclarationIdentity: Codable, Equatable, Sendable {
    let id: String
    let editionID: ScriptureEditionID
    let declarationSHA256: String
}

struct ScriptureQualificationPairIdentity: Codable, Equatable, Sendable {
    let id: String
    let englishItemID: String
    let simplifiedChineseItemID: String
    let partition: ScriptureQualificationPartition
}

struct ScriptureQualificationFailureIdentity: Codable, Equatable, Sendable {
    let pairID: String
    let itemID: String
    let lane: ScriptureQualificationLane
    let code: String
}

enum ScriptureQualificationLane: String, Codable, CaseIterable, Hashable, Sendable {
    case englishASR = "english-asr"
    case simplifiedChineseASR = "simplified-chinese-asr"
    case englishToSimplifiedChineseCleanText = "english-to-simplified-chinese-clean-text"
    case simplifiedChineseToEnglishCleanText = "simplified-chinese-to-english-clean-text"
    case englishASRToSimplifiedChinese = "english-asr-to-simplified-chinese"
    case simplifiedChineseASRToEnglish = "simplified-chinese-asr-to-english"

    var metricUnit: ScriptureQualificationMetricUnit {
        switch self {
        case .englishASR, .simplifiedChineseToEnglishCleanText,
            .simplifiedChineseASRToEnglish:
            .word
        case .simplifiedChineseASR, .englishToSimplifiedChineseCleanText,
            .englishASRToSimplifiedChinese:
            .character
        }
    }
}

enum ScriptureQualificationMetricUnit: String, Codable, Sendable {
    case word
    case character
}

enum ScriptureQualificationFailureCode: String, Codable, Hashable, Sendable {
    case audioDecodeFailed = "audio-decode-failed"
    case asrFailed = "asr-failed"
    case translationFailed = "translation-failed"
    case upstreamASRFailed = "upstream-asr-failed"
    case metricFailed = "metric-failed"
}

struct ScriptureQualificationAggregate: Codable, Equatable, Sendable {
    let partition: ScriptureQualificationPartition
    let lane: ScriptureQualificationLane
    let metricUnit: ScriptureQualificationMetricUnit
    let attemptCount: Int
    let successCount: Int
    let failureCount: Int
    let editCount: Int
    let referenceUnitCount: Int
    let errorRate: Double
    let referencePunctuationCount: Int
    let hypothesisPunctuationCount: Int
    let punctuationEditCount: Int
    let punctuationErrorRate: Double
    let audioSeconds: Double
    let runtimeSeconds: Double
    let failureCounts: [String: Int]
}

struct ScriptureQualificationLaneGate: Codable, Equatable, Sendable {
    let partition: ScriptureQualificationPartition
    let lane: ScriptureQualificationLane
    let minimumAttempts: Int
    let requiresZeroFailures: Bool
    let maximumErrorRate: Double
    let maximumAverageRuntimeSeconds: Double
    let maximumRealTimeFactor: Double?
    let observedAttempts: Int
    let observedFailures: Int
    let observedErrorRate: Double
    let observedAverageRuntimeSeconds: Double
    let observedRealTimeFactor: Double?
    let passed: Bool
}
