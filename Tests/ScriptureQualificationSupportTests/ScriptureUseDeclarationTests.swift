import ScriptureQualificationSupport
import Testing

@Suite struct ScriptureUseDeclarationTests {
    @Test func rejectsMissingASREvaluationUseDeclaration() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var declarations = try #require(object["sourceDeclarations"] as? [[String: Any]])
        var uses = try #require(declarations[0]["permittedUses"] as? [String: Any])
        uses["asrEvaluationAllowed"] = false
        declarations[0]["permittedUses"] = uses
        object["sourceDeclarations"] = declarations
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func acceptsProjectAndIndividualSourceDeclarers() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var declarations = try #require(object["sourceDeclarations"] as? [[String: Any]])
        declarations[1]["declaredBy"] = "Individual Local Tester"
        object["sourceDeclarations"] = declarations
        try fixture.writeManifestObject(object)

        #expect(try fixture.load().sourceDeclarations.count == 2)
    }

    @Test func rejectsMissingNonWeightModelAdjustmentDeclaration() throws {
        let fixture = try SyntheticScriptureCorpusFixture()
        var object = try fixture.manifestObject()
        var declarations = try #require(object["sourceDeclarations"] as? [[String: Any]])
        var uses = try #require(declarations[0]["permittedUses"] as? [String: Any])
        uses["modelAdjustmentAllowed"] = false
        declarations[0]["permittedUses"] = uses
        object["sourceDeclarations"] = declarations
        try fixture.writeManifestObject(object)

        #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
    }

    @Test func rejectsTrainingOrRedistributionUse() throws {
        for key in ["modelTrainingAllowed", "redistributionAllowed"] {
            let fixture = try SyntheticScriptureCorpusFixture()
            var object = try fixture.manifestObject()
            var declarations = try #require(object["sourceDeclarations"] as? [[String: Any]])
            var uses = try #require(declarations[0]["permittedUses"] as? [String: Any])
            uses[key] = true
            declarations[0]["permittedUses"] = uses
            object["sourceDeclarations"] = declarations
            try fixture.writeManifestObject(object)

            #expect(throws: ScriptureQualificationError.self) { _ = try fixture.load() }
        }
    }
}
