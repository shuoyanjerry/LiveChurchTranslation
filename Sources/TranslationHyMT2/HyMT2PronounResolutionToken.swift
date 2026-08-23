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
}
