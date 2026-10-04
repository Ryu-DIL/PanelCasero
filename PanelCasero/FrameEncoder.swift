import CoreImage
import ImageIO

/// Convierte fotogramas de la cámara en JPEG (se usa siempre desde la cola de la cámara).
final class FrameEncoder {
    private let context = CIContext(options: nil)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    func jpeg(from buffer: CVPixelBuffer, quality: CGFloat) -> Data? {
        let image = CIImage(cvPixelBuffer: buffer)
        let key = CIImageRepresentationOption(rawValue: kCGImageDestinationLossyCompressionQuality as String)
        return context.jpegRepresentation(of: image, colorSpace: colorSpace, options: [key: quality])
    }
}
