import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounDeterministicRepairerTests {
    @Test func repairsGenderFamilyAndPreservesCapitalization() throws {
        let plan = try makePronounPlan(
            source: "她继续。",
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "\(anchored(plan, 0, "He")) continued."

        let repaired = HyMT2PronounDeterministicRepairer.repair(output, plan: plan)

        #expect(repaired == "\(anchored(plan, 0, "She")) continued.")
    }

    @Test func repairsObjectMorphology() throws {
        let plan = try makePronounPlan(
            source: "她继续。",
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "The church welcomed \(anchored(plan, 0, "him"))."

        let repaired = HyMT2PronounDeterministicRepairer.repair(output, plan: plan)

        #expect(repaired == "The church welcomed \(anchored(plan, 0, "her")).")
    }

    @Test func usesSourcePossessiveShapeToChooseDeterminer() throws {
        let plan = try makePronounPlan(
            source: "她的见证。",
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "\(anchored(plan, 0, "his")) testimony."

        let repaired = HyMT2PronounDeterministicRepairer.repair(output, plan: plan)

        #expect(repaired == "\(anchored(plan, 0, "her")) testimony.")
    }

    @Test func refusesSubjectRepairThatWouldBreakAgreement() throws {
        let plan = try makePronounPlan(
            source: "他继续。",
            guidance: [guidance(0, .unresolvedSpokenMandarin)]
        )
        let output = "\(anchored(plan, 0, "he")) continues."

        #expect(HyMT2PronounDeterministicRepairer.repair(output, plan: plan) == output)
    }

    @Test func refusesTamperedResolutionCode() throws {
        let plan = try makePronounPlan(
            source: "她继续。",
            guidance: [guidance(0, .verifiedFemale)]
        )
        let output = "\(anchored(plan, 0, "he")) continued."
        let tampered = output.replacingOccurrences(of: "F>", with: "M>")

        #expect(HyMT2PronounDeterministicRepairer.repair(tampered, plan: plan) == tampered)
    }
}
