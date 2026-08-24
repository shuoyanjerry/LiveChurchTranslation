import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum InvitationQRCode {
    private static let renderer = InvitationQRCodeRenderer()
    private static let quietZoneModules = CGFloat(4)
    private static let scale = CGFloat(8)

    static func image(for url: URL) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage else { return nil }
        let translated = output.transformed(
            by: CGAffineTransform(
                translationX: quietZoneModules,
                y: quietZoneModules
            )
        )
        let background = CIImage(color: .white).cropped(
            to: CGRect(
                x: 0,
                y: 0,
                width: output.extent.width + quietZoneModules * 2,
                height: output.extent.height + quietZoneModules * 2
            )
        )
        let rendered = translated.composited(over: background).transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        guard let image = renderer.createImage(rendered) else {
            return nil
        }
        return NSImage(
            cgImage: image,
            size: NSSize(width: rendered.extent.width, height: rendered.extent.height)
        )
    }
}

private final class InvitationQRCodeRenderer: @unchecked Sendable {
    private let context = CIContext(options: [.cacheIntermediates: false])

    func createImage(_ image: CIImage) -> CGImage? {
        context.createCGImage(image, from: image.extent)
    }
}
