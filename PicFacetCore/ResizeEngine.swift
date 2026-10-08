import Foundation
import CoreGraphics

public enum ResizeOperation: Hashable, Codable, Sendable {
    case percent(Int)
    case width(Int)
    case height(Int)
    /// Fit the longer side within this many pixels. Never enlarges.
    case longEdge(Int)

    public var displayName: String {
        switch self {
        case .percent(let percent):
            return "Resize to \(percent)%"
        case .width(let width):
            return "Set width to \(width) px"
        case .height(let height):
            return "Set height to \(height) px"
        case .longEdge(let edge):
            return "Fit within \(edge) px"
        }
    }
}

struct ResizeEngine {

    // MARK: - Resize

    /// Resamples cgImage to newSize using high-quality Lanczos interpolation via CGContext.
    static func resize(_ cgImage: CGImage, toSize size: CGSize) throws -> CGImage {
        guard let ctx = Canvas.make(width: Int(size.width), height: Int(size.height), like: cgImage) else {
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

    static func size(for image: CGImage, operation: ResizeOperation, proportional: Bool) -> CGSize {
        switch operation {
        case .percent(let percent):
            return size(for: image, byPercent: Double(percent))
        case .width(let width):
            return size(for: image, maxWidth: width, proportional: proportional)
        case .height(let height):
            return size(for: image, maxHeight: height, proportional: proportional)
        case .longEdge(let edge):
            let long = max(image.width, image.height)
            guard long > edge else { return CGSize(width: image.width, height: image.height) }
            return size(for: image, byPercent: Double(edge) / Double(long) * 100)
        }
    }

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

/// 8-bit RGBA bitmap contexts for drawing. Keeps the source's colour space when
/// it is RGB; indexed (GIF), grey and CMYK sources draw into sRGB, since
/// CGContext can't render RGBA into those.
enum Canvas {
    static func make(width: Int, height: Int, like image: CGImage) -> CGContext? {
        guard width > 0, height > 0 else { return nil }
        var space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        if space.model != .rgb { space = CGColorSpace(name: CGColorSpace.sRGB)! }
        // 16-bit TIFFs are intentionally downsampled to 8bpc.
        return CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}
