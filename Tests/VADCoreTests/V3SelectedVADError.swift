import Foundation

enum V3SelectedVADError: Error, Equatable {
    case disabled
    case unsupportedEnvironment(String)
    case missingOutput
    case unsafeInput
    case unsafeOutput
    case provenanceMismatch(String)
    case invalidManifest(String)
    case invalidWAV
    case incompleteRead
    case parityMismatch
    case storageFailure
    case privacyFailure
}

enum V3SelectedVADFailureCode: String, Codable, Sendable {
    case detectorInitialization
    case invalidWAV
    case incompleteRead
    case parityMismatch
    case processingFailure
    case sourceMutation
}
