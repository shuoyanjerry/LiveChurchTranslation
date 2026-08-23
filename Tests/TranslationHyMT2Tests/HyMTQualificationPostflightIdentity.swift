import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMTQualificationPostflightIdentity {
    static func provider(
        configuration: HyMTQualificationConfiguration,
        provenance: TranslationExecutionProvenance
    ) -> TranslationQualificationProvider {
        let identifier = HyMT2TranslationProvider(
            helperExecutableURL: configuration.helperURL,
            configuration: configuration.providerConfiguration
        ).identifier
        return TranslationQualificationProvider(
            identifier: identifier,
            modelRevision: HyMTQualificationConfiguration.modelRevision,
            modelSHA256: provenance.model.sha256,
            runtimeRevision: HyMTQualificationConfiguration.runtimeRevision,
            runtimeSHA256: provenance.helper.sha256,
            settings: configuration.providerSettings
        )
    }

    static func environment(
        configuration: HyMTQualificationConfiguration
    ) -> TranslationQualificationEnvironment {
        HyMTQualificationHostEnvironment.capture(
            backgroundLoad: configuration.backgroundLoad
        )
    }
}
