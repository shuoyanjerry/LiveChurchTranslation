import DiscourseResolutionAPI
import TranslationAPI

struct RecoveryProcessingContext: Sendable {
    let translation: [TranslationContextEntry]
    let discourse: [VerifiedDiscourseTurn]
}
