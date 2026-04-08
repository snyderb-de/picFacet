import Foundation
import ImageIO
import CoreGraphics

struct ConversionEngine {

    // MARK: - Read

    /// Returns the CGImage and raw metadata dictionary from any ImageIO-supported file.
    static func readImage(from url: URL) throws -> (CGImage, [String: Any]) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PicFacetError.unreadableFile(url)
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PicFacetError.unreadableFile(url)
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        return (cgImage, properties)
    }

    // MARK: - Write

    /// Writes a CGImage to disk using ImageIO. Properties carry EXIF/DPI metadata.
    static func writeImage(
        _ cgImage: CGImage,
        properties: [String: Any],
        to url: URL,
        format: ImageFormat
    ) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utiString as CFString,
            1,
            nil
        ) else {
            throw PicFacetError.writeFailed(url)
        }

        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw PicFacetError.writeFailed(url)
        }
    }
}
