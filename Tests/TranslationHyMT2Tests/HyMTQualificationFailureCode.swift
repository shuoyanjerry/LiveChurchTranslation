@testable import TranslationHyMT2

enum HyMTQualificationFailureCode {
    static func make(_ error: any Error) -> String {
        HyMT2SafeFailureCode.make(error)
    }
}
