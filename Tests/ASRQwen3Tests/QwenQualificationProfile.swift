enum QwenQualificationProfile: String, Equatable, Sendable {
    case baseline2
    case threads4
    case threads6

    init(environmentValue: String?) throws {
        guard let environmentValue else {
            self = .baseline2
            return
        }
        guard let profile = Self(rawValue: environmentValue), profile != .baseline2 else {
            throw QwenQualificationProfileError.unsupportedValue(environmentValue)
        }
        self = profile
    }

    var inferenceThreads: Int {
        switch self {
        case .baseline2: 2
        case .threads4: 4
        case .threads6: 6
        }
    }
}

enum QwenQualificationProfileError: Error, Equatable {
    case unsupportedValue(String)
}
