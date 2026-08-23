import Foundation

enum ScriptureModelQualificationError: Error, Equatable {
    case invalidEnvironment(String)
    case invalidCorpus
    case invalidReference
    case invalidAudio
    case modelIdentityMismatch(String)
    case reportWriteFailed
}
