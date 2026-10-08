import Foundation
import CoreGraphics
import Accelerate
import libwebp

/// WebP encoding via the bundled libwebp, since ImageIO can only decode WebP.
/// Pixels are converted to sRGB (WebP has no colour profile here) and no
/// metadata is written: EXIF, GPS and DPI are dropped.
enum WebPEncoder {
    /// WebP's format limit per side.
    static let maxDimension = 16_383

    /// `quality` 0…1; nil uses 0.8. 1.0 encodes losslessly.
    static func encode(_ image: CGImage, quality: Double?) throws -> Data {
        let width = image.width, height = image.height
        guard width <= maxDimension, height <= maxDimension else {
            throw PicFacetError.customError("WebP images can be at most \(maxDimension) px per side; this one is \(width) × \(height). Resize it first.")
        }
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let pixels = ctx.data else {
            throw PicFacetError.customError("Couldn't encode WebP.")
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // libwebp expects straight (non-premultiplied) alpha.
        var buffer = vImage_Buffer(data: pixels, height: vImagePixelCount(height),
                                   width: vImagePixelCount(width), rowBytes: ctx.bytesPerRow)
        vImageUnpremultiplyData_RGBA8888(&buffer, &buffer, vImage_Flags(kvImageNoFlags))

        let rgba = pixels.assumingMemoryBound(to: UInt8.self)
        let stride = Int32(ctx.bytesPerRow)
        let q = min(1, max(0, quality ?? 0.8))
        var output: UnsafeMutablePointer<UInt8>?
        let size = q >= 1
            ? WebPEncodeLosslessRGBA(rgba, Int32(width), Int32(height), stride, &output)
            : WebPEncodeRGBA(rgba, Int32(width), Int32(height), stride, Float(q * 100), &output)
        guard size > 0, let output else {
            throw PicFacetError.customError("Couldn't encode WebP.")
        }
        defer { WebPFree(output) }
        return Data(bytes: output, count: size)
    }
}
