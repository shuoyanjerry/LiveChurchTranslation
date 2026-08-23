import Foundation

enum ModelHTTPResponseValidator {
    static func validate(
        response: URLResponse,
        downloadedFile: URL,
        maximumBytes: Int64
    ) throws -> ModelHTTPTransferResult {
        guard let response = response as? HTTPURLResponse else {
            throw ModelHTTPTransportError.nonHTTPResponse
        }
        let contentLength =
            response.expectedContentLength > 0
            ? response.expectedContentLength
            : nil
        if let contentLength, contentLength > maximumBytes {
            throw ModelHTTPTransportError.responseTooLarge(maximumBytes: maximumBytes)
        }
        guard try fileSize(at: downloadedFile) <= maximumBytes else {
            throw ModelHTTPTransportError.responseTooLarge(maximumBytes: maximumBytes)
        }
        guard (200...299).contains(response.statusCode) else {
            throw ModelHTTPTransportError.rejectedStatus(response.statusCode)
        }
        return ModelHTTPTransferResult(
            statusCode: response.statusCode,
            contentLength: contentLength
        )
    }

    private static func fileSize(at url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
