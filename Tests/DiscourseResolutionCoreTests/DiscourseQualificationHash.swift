import Foundation
import TranslationQualificationSupport

enum DiscourseQualificationHash {
    static func text(_ value: String) -> String {
        TranslationQualificationSHA256.hash(data: Data(value.utf8))
    }
}
