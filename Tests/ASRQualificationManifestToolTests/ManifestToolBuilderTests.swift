import Testing

@Suite struct ManifestToolBuilderTests {
    @Test func freezesProvenanceReferenceAndScoringPolicy() throws {
        let documents = try ManifestToolSourceFixture.documents(allowsEdges: false)
        let build = try ManifestToolBuilder(expectedSegmentCount: 1).make(
            documents: documents
        )
        let clip = try #require(build.manifest.clips.first)

        #expect(build.manifest.corpusID == "public-domain-mandarin-scripture-v1")
        #expect(build.manifest.provenance.generatorRevision == "abc123+dirty")
        #expect(
            build.manifest.provenance.sourceVADReportSHA256
                == ManifestToolHashing.sha256(documents.vadData)
        )
        #expect(
            clip.referenceSHA256
                == ManifestToolHashing.referenceText(ManifestToolSourceFixture.referenceText)
        )
        #expect(!clip.allowsHypothesisEdgeInsertions)
        #expect(clip.segments[0].syntheticPaddingSamples == 0)
    }

    @Test func rejectsReferenceTextDrift() throws {
        let documents = try ManifestToolDocuments(
            vadData: ManifestToolVADFixture.data(),
            corpusData: ManifestToolSourceFixture.corpusData(),
            referenceData: ManifestToolSourceFixture.referenceData(referenceText: "神爱世人。")
        )

        expectBuilderError(.referenceTextMismatch("clip-a"), documents: documents)
    }

    @Test func rejectsNonzeroEmissionPadding() throws {
        let documents = try ManifestToolSourceFixture.documents(padding: 1)

        expectBuilderError(
            .invalidBoundary(clipID: "clip-a", sequence: 1),
            documents: documents
        )
    }

    @Test func rejectsDuplicateSourceIDsWithoutDictionaryTrap() throws {
        let corpus = try ManifestToolSourceFixture.corpusData { root in
            var clips = root["clips"] as? [[String: Any]] ?? []
            clips.append(clips[0])
            root["clips"] = clips
        }
        let documents = try ManifestToolDocuments(
            vadData: ManifestToolVADFixture.data(),
            corpusData: corpus,
            referenceData: ManifestToolSourceFixture.referenceData()
        )

        expectBuilderError(
            .duplicateID(source: "corpus", id: "clip-a"),
            documents: documents
        )
    }
}

private func expectBuilderError(
    _ expected: ManifestToolError,
    documents: ManifestToolDocuments
) {
    do {
        _ = try ManifestToolBuilder(expectedSegmentCount: 1).make(documents: documents)
        Issue.record("Expected \(expected)")
    } catch let error as ManifestToolError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}
