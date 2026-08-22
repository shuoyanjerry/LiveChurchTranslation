import Foundation
import SemanticEndpointAPI
import SmartTurnOnnxRuntimeC

final class SmartTurnOnnxSession {
    private var handle: OpaquePointer?

    static var runtimeVersion: String {
        guard let version = st_ort_runtime_version() else { return "unavailable" }
        return String(cString: version)
    }

    init(modelLocation: URL) throws {
        var createdHandle: OpaquePointer?
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = modelLocation.withUnsafeFileSystemRepresentation { path in
            st_ort_create_session(path, &createdHandle, &errorMessage)
        }
        guard status == 0, let createdHandle else {
            throw SemanticEndpointError.modelLoadFailed(Self.consume(errorMessage))
        }
        handle = createdHandle
    }

    deinit {
        st_ort_destroy_session(handle)
    }

    func predict(features: inout [Float]) throws -> Float {
        guard let handle else {
            throw SemanticEndpointError.modelNotLoaded
        }
        var probability: Float = .nan
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = features.withUnsafeMutableBufferPointer { buffer in
            st_ort_predict(
                handle,
                buffer.baseAddress,
                buffer.count,
                &probability,
                &errorMessage
            )
        }
        guard status == 0 else {
            throw SemanticEndpointError.inferenceFailed(Self.consume(errorMessage))
        }
        return probability
    }

    private static func consume(_ pointer: UnsafeMutablePointer<CChar>?) -> String {
        guard let pointer else { return "ONNX Runtime returned no diagnostic message." }
        defer { st_ort_free_error(pointer) }
        return String(cString: pointer)
    }
}
