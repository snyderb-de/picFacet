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
        size(width: image.width, height: image.height, operation: operation, proportional: proportional)
    }

    static func size(width: Int, height: Int, operation: ResizeOperation, proportional: Bool) -> CGSize {
        let w = CGFloat(width), h = CGFloat(height)
        switch operation {
        case .percent(let percent):
            let scale = CGFloat(percent) / 100
            return CGSize(width: w * scale, height: h * scale)
        case .width(let target):
            return CGSize(width: CGFloat(target), height: proportional ? h * CGFloat(target) / w : h)
        case .height(let target):
            return CGSize(width: proportional ? w * CGFloat(target) / h : w, height: CGFloat(target))
        case .longEdge(let edge):
            let long = max(width, height)
            guard long > edge else { return CGSize(width: w, height: h) }
            let scale = CGFloat(edge) / CGFloat(long)
            return CGSize(width: w * scale, height: h * scale)
        }
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
