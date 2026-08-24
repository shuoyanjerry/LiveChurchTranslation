import AppKit
import Foundation
import Vision
@testable import LiveReader
import Testing

@Suite struct InvitationQRCodeTests {
    @Test func rendersInvitationEntirelyOnDevice() throws {
        let url = try #require(
            URL(
                string: "http://live-church-translation.local:8042/"
                    + "#invite=16f69c35-a930-41c5-8e85-f0ed58964852."
                    + "vD6NE2o83KQTPZ1GaBfws74OLiRcAmhjkE9UX5pSNqY"
            )
        )

        let image = try #require(InvitationQRCode.image(for: url))

        #expect(image.size.width >= 160)
        #expect(image.size.height >= 160)
        #expect(image.tiffRepresentation != nil)

        let cgImage = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: cgImage).perform([request])

        let payloads = request.results?.compactMap(\.payloadStringValue) ?? []
        #expect(payloads == [url.absoluteString])
    }
}
