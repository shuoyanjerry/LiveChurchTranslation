import ModelRuntimeAPI

/// Models required by one live translation session.
public struct SessionModelDescriptors: Sendable {
    public let speechRecognition: ModelDescriptor
    public let translation: ModelDescriptor

    public init(
        speechRecognition: ModelDescriptor,
        translation: ModelDescriptor
    ) {
        self.speechRecognition = speechRecognition
        self.translation = translation
    }
}
