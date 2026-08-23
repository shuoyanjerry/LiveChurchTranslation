import Foundation
import TranslationQualificationSupport

enum HyMTQualificationTheologyCatalog {
    struct Entry: Equatable, Sendable {
        let label: String
        let preferredTarget: String
        let acceptedTargets: [String]
        let required: Bool

        var expectation: TranslationQualificationTermExpectation {
            TranslationQualificationTermExpectation(
                source: label,
                preferredTarget: preferredTarget,
                acceptedTargets: acceptedTargets,
                required: required
            )
        }
    }

    static let policyID = "hymt-qualification-theology-surface-v1"

    static func expectation(
        forExactLabel label: String
    ) throws -> TranslationQualificationTermExpectation {
        let matches = entries.filter { $0.label == label }
        guard matches.count == 1, let entry = matches.first else { throw catalogError }
        return entry.expectation
    }

    static var catalogSHA256: String {
        catalogSHA256(for: entries, policyID: policyID)
    }

    static func catalogSHA256(for entries: [Entry], policyID: String) -> String {
        let records = entries.sorted { $0.label < $1.label }.map {
            catalogRecord($0, policyID: policyID)
        }
        return TranslationQualificationSHA256.hash(data: Data(records.joined().utf8))
    }

    static let entries: [Entry] = [
        entry("救恩", "salvation", ["saved", "saving"]),
        entry("恩典", "grace"),
        entry("称义", "justification", ["justified", "justify", "justifies"]),
        entry("稱義", "justification", ["justified", "justify", "justifies"]),
        entry(
            "因信称义",
            "justification by faith",
            ["justified by faith", "justification through faith"]
        ),
        entry("成圣", "sanctification", ["sanctified", "sanctify", "sanctifies"]),
        entry("成聖", "sanctification", ["sanctified", "sanctify", "sanctifies"]),
        entry("重生", "regeneration", ["born again", "new birth"]),
        entry("赎罪", "atonement", ["atone", "atoned", "atones", "atoning"]),
        entry("贖罪", "atonement", ["atone", "atoned", "atones", "atoning"]),
        entry("救赎", "redemption", ["redeem", "redeemed", "redeems", "redeeming"]),
        entry("救贖", "redemption", ["redeem", "redeemed", "redeems", "redeeming"]),
        entry("三位一体", "the Trinity", ["Trinitarian", "the triune God"]),
        entry("三位一體", "the Trinity", ["Trinitarian", "the triune God"]),
        entry("圣灵", "the Holy Spirit", ["Holy Spirit"]),
        entry("聖靈", "the Holy Spirit", ["Holy Spirit"]),
        entry("团契", "fellowship"),
        entry("團契", "fellowship"),
        entry("事奉", "ministry", ["serve", "serving", "service"]),
        entry("侍奉", "ministry", ["serve", "serving", "service"]),
        entry("圣餐", "the Lord's Supper", ["Holy Communion", "Communion"]),
        entry("聖餐", "the Lord's Supper", ["Holy Communion", "Communion"]),
        entry("洗礼", "baptism", ["baptized", "baptize", "baptizes", "baptizing"]),
        entry("洗禮", "baptism", ["baptized", "baptize", "baptizes", "baptizing"]),
        entry("福音", "the gospel", ["gospel"]),
        entry("基督", "Christ"),
        entry("十字架", "the cross", ["cross"]),
        entry("永生", "eternal life"),
        entry("悔改", "repentance", ["repent", "repented", "repents", "repenting"]),
        entry("罪", "sin", ["sins", "sinned", "sinning"]),
    ]

    private static func entry(
        _ label: String,
        _ preferredTarget: String,
        _ acceptedTargets: [String] = []
    ) -> Entry {
        Entry(
            label: label,
            preferredTarget: preferredTarget,
            acceptedTargets: acceptedTargets,
            required: true
        )
    }

    private static func catalogRecord(_ entry: Entry, policyID: String) -> String {
        let values =
            [
                policyID,
                entry.label,
                entry.preferredTarget,
                entry.required ? "required" : "preferred",
                String(entry.acceptedTargets.count),
            ] + entry.acceptedTargets
        return values.map(lengthPrefixed).joined(separator: "\u{1E}") + "\n"
    }

    private static func lengthPrefixed(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static let catalogError = TranslationQualificationError.invalidManifest(
        "manifest theology term lacks a unique exact qualification catalog entry"
    )
}
