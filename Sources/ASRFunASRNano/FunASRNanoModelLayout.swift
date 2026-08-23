import ASRAPI
import Foundation

struct FunASRNanoModelLayout: Sendable {
    let encoderAdaptor: URL
    let languageModel: URL
    let embedding: URL
    let tokenizer: URL

    init(directory: URL) throws {
        try FunASRNanoModelVerifier().verify(directory: directory)
        encoderAdaptor = directory.appending(path: "encoder_adaptor.int8.onnx")
        languageModel = directory.appending(path: "llm.int8.onnx")
        embedding = directory.appending(path: "embedding.int8.onnx")
        tokenizer = directory.appending(path: "Qwen3-0.6B", directoryHint: .isDirectory)
    }
}
