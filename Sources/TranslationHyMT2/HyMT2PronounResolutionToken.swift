import TranslationAPI

enum HyMT2PronounResolutionToken {
    static func value(for resolution: TranslationPronounResolution) -> String {
        switch resolution {
        case .unresolvedSpokenMandarin:
            "QLR_UNRESOLVED"
        case .verifiedFemale:
            "QLR_VERIFIED_FEMALE"
        case .verifiedMale:
            "QLR_VERIFIED_MALE"
        case .verifiedDeity:
            "QLR_VERIFIED_DEITY"
        }
    }

    static func compactCode(for resolution: TranslationPronounResolution) -> Character {
        switch resolution {
        case .unresolvedSpokenMandarin: "N"
        case .verifiedFemale: "F"
        case .verifiedMale: "M"
        case .verifiedDeity: "D"
        }
    }

    static func value(forCompactCode code: Character) -> String? {
        switch code {
        case "N": value(for: .unresolvedSpokenMandarin)
        case "F": value(for: .verifiedFemale)
        case "M": value(for: .verifiedMale)
        case "D": value(for: .verifiedDeity)
        default: nil
        }
    }
}
