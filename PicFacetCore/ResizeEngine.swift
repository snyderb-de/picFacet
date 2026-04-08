import Foundation
import CoreGraphics

struct ResizeEngine {

    // MARK: - Resize

    /// Resamples cgImage to newSize using high-quality Lanczos interpolation via CGContext.
    static func resize(_ cgImage: CGImage, toSize size: CGSize) throws -> CGImage {
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        // Always render at 8bpc premultiplied — covers JPEG, PNG, WebP, HEIC.
        // 16-bit TIFFs are intentionally downsampled; add 16bpc path later if needed.
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw PicFacetError.resizeFailed
        }

        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))

        guard let result = ctx.makeImage() else {
            throw PicFacetError.resizeFailed
        }
        return result
    }

    // MARK: - Size calculators

    static func size(for image: CGImage, byPercent percent: Double) -> CGSize {
        let scale = CGFloat(percent / 100.0)
        return CGSize(width: CGFloat(image.width) * scale,
                      height: CGFloat(image.height) * scale)
    }

    static func size(for image: CGImage, maxWidth width: Int, proportional: Bool) -> CGSize {
        guard proportional else {
            return CGSize(width: width, height: image.height)
        }
        let scale = CGFloat(width) / CGFloat(image.width)
        return CGSize(width: CGFloat(width),
                      height: CGFloat(image.height) * scale)
    }

    static func size(for image: CGImage, maxHeight height: Int, proportional: Bool) -> CGSize {
        guard proportional else {
            return CGSize(width: image.width, height: height)
        }
        let scale = CGFloat(height) / CGFloat(image.height)
        return CGSize(width: CGFloat(image.width) * scale,
                      height: CGFloat(height))
    }
}
