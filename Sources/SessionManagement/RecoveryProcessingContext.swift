import DiscourseResolutionAPI
import TranslationAPI

struct RecoveryProcessingContext: Sendable {
    let presentationSequence: Int
    let translation: [TranslationContextEntry]
    let discourse: [VerifiedDiscourseTurn]
}
