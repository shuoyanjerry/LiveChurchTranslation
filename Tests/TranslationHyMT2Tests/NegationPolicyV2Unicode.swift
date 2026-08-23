enum NegationPolicyV2Unicode {
    static func sourceIsUnsafe(_ value: String) -> Bool {
        value.unicodeScalars.contains(where: scalarIsUnsafe)
    }

    static func targetIsUnsafe(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            if scalar == "’" { return false }
            return scalarIsUnsafe(scalar)
                || (scalar.properties.isAlphabetic && !scalar.isASCII)
        }
    }

    private static func scalarIsUnsafe(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.properties.generalCategory {
        case .control, .enclosingMark, .format, .nonspacingMark, .privateUse,
            .spacingMark, .surrogate:
            true
        default:
            false
        }
    }
}
