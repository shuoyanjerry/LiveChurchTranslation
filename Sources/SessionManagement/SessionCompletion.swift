import SessionManagementAPI

struct SessionCompletion: Sendable {
    let outcome: LiveSessionFinalizationOutcome
    let message: String
    let errorMessage: String?
}
