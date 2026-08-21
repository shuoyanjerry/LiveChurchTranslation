import ASRAPI
import Foundation

struct Qwen3ModelLayout: Sendable {
    let convFrontend: URL
    let encoder: URL
    let decoder: URL
    let tokenizer: URL

    init(directory: URL, fileManager: FileManager = .default) throws {
        convFrontend = directory.appending(path: "conv_frontend.onnx")
        encoder = directory.appending(path: "encoder.int8.onnx")
        decoder = directory.appending(path: "decoder.int8.onnx")
        tokenizer = directory.appending(path: "tokenizer", directoryHint: .isDirectory)

        let required = [convFrontend, encoder, decoder]
        guard required.allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else {
            throw ASRError.inferenceFailed("The Qwen3-ASR model directory is incomplete.")
        }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: tokenizer.path, isDirectory: &isDirectory),
            isDirectory.boolValue
        else {
            throw ASRError.inferenceFailed("The Qwen3-ASR tokenizer directory is missing.")
        }
    }
}
