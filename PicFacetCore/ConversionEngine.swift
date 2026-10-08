import Foundation
import ImageIO
import CoreGraphics

struct ConversionEngine {

    // MARK: - Read

    /// Returns the CGImage and raw metadata dictionary from any ImageIO-supported file.
    /// Rotated photos (EXIF orientation other than "up") come back upright with
    /// orientation reset to 1, so crops, watermarks and long-edge fits act on
    /// the image as the user sees it.
    static func readImage(from url: URL) throws -> (CGImage, [String: Any]) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw PicFacetError.unreadableFile(url)
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PicFacetError.unreadableFile(url)
        }
        var properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        let orientation = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.intValue ?? 1
        guard orientation != 1 else { return (cgImage, properties) }

        // A full-size "thumbnail" with the transform applied is the upright image.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(cgImage.width, cgImage.height)
        ]
        guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return (cgImage, properties)
        }
        properties = MetadataEngine.resettingOrientation(properties)
        return (upright, properties)
    }

    /// Renders every page of a PDF at `dpi` on a white background.
    /// Pages are capped at `maxSide` pixels on their longer side.
    static func readPDFPages(from url: URL, dpi: Int, maxSide: Int = 10_000) throws -> [CGImage] {
        guard let document = CGPDFDocument(url as CFURL), document.numberOfPages > 0 else {
            throw PicFacetError.unreadableFile(url)
        }
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        var pages: [CGImage] = []
        for number in 1...document.numberOfPages {
            guard let page = document.page(at: number) else { continue }
            let box = page.getBoxRect(.cropBox)
            let rotation = ((page.rotationAngle % 360) + 360) % 360
            let upright = rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)

            var scale = CGFloat(dpi) / 72
            let longest = max(upright.width, upright.height) * scale
            if longest > CGFloat(maxSide) { scale *= CGFloat(maxSide) / longest }

            let width = max(1, Int((upright.width * scale).rounded()))
            let height = max(1, Int((upright.height * scale).rounded()))
            guard let ctx = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { throw PicFacetError.unreadableFile(url) }

            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.interpolationQuality = .high
            ctx.scaleBy(x: scale, y: scale)
            switch rotation {
            case 90:
                ctx.translateBy(x: 0, y: box.width)
                ctx.rotate(by: -.pi / 2)
            case 180:
                ctx.translateBy(x: box.width, y: box.height)
                ctx.rotate(by: .pi)
            case 270:
                ctx.translateBy(x: box.height, y: 0)
                ctx.rotate(by: .pi / 2)
            default:
                break
            }
            ctx.translateBy(x: -box.origin.x, y: -box.origin.y)
            ctx.drawPDFPage(page)

            guard let image = ctx.makeImage() else { throw PicFacetError.unreadableFile(url) }
            pages.append(image)
        }
        return pages
    }

    // MARK: - Write

    /// Encodes a CGImage with ImageIO. Properties carry EXIF/DPI metadata.
    /// `quality` (0…1) applies to lossy formats only; nil uses the encoder default.
    static func encode(
        _ cgImage: CGImage,
        properties: [String: Any],
        format: ImageFormat,
        quality: Double? = nil
    ) throws -> Data {
        if format == .webp {
            return try WebPEncoder.encode(cgImage, quality: quality)
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utiString as CFString, 1, nil) else {
            throw unsupported(format)
        }

        var props = MetadataEngine.updatingPixelSize(properties, width: cgImage.width, height: cgImage.height)
        if let quality, format.isLossy {
            props[kCGImageDestinationLossyCompressionQuality as String] = min(1, max(0, quality))
        }
        CGImageDestinationAddImage(destination, cgImage, props as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw PicFacetError.customError("Couldn't encode \(format.displayName).")
        }
        return data as Data
    }

    /// Writes a CGImage to disk using ImageIO. Properties carry EXIF/DPI metadata.
    static func writeImage(
        _ cgImage: CGImage,
        properties: [String: Any],
        to url: URL,
        format: ImageFormat,
        quality: Double? = nil
    ) throws {
        let data = try encode(cgImage, properties: properties, format: format, quality: quality)
        do {
            try data.write(to: url)
        } catch {
            throw PicFacetError.writeFailed(url)
        }
    }

    /// True when this Mac's ImageIO can write the format.
    static func canWrite(_ format: ImageFormat) -> Bool {
        format == .webp || WritableTypes.all.contains(format.utiString)
    }

    private static func unsupported(_ format: ImageFormat) -> PicFacetError {
        .customError("\(format.displayName) encoding is not available on this Mac. Try JPEG, PNG, HEIC, AVIF or WebP instead.")
    }

    private enum WritableTypes {
        static let all: Set<String> = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
    }
}
