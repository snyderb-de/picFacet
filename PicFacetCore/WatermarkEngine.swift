import Foundation
import CoreGraphics
import CoreText
import ImageIO

/// Stamps a text or logo watermark. Sizes are a share of the image's short
/// side, so the mark looks the same on a thumbnail and a full-size photo.
enum WatermarkEngine {
    static func apply(_ mark: Watermark, to image: CGImage) throws -> CGImage {
        guard let ctx = Canvas.make(width: image.width, height: image.height, like: image) else {
            throw PicFacetError.customError("Failed to add watermark")
        }
        let canvas = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: canvas)

        let short = CGFloat(min(image.width, image.height))
        let margin = short * 0.03
        ctx.setAlpha(CGFloat(min(1, max(0, mark.opacity))))

        if let logoPath = mark.logoPath {
            let logo = try loadLogo(logoPath)
            let width = short * 0.2 * mark.size.scale
            let height = width * CGFloat(logo.height) / CGFloat(max(1, logo.width))
            let origin = place(CGSize(width: width, height: height), in: canvas, at: mark.position, margin: margin)
            ctx.draw(logo, in: CGRect(origin: origin, size: CGSize(width: width, height: height)))
        } else {
            let fontSize = max(10, short * 0.045 * mark.size.scale)
            let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, fontSize, nil)
                ?? CTFontCreateWithName("Helvetica-Bold" as CFString, fontSize, nil)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1)
            ]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: mark.text, attributes: attributes))
            var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
            let size = CGSize(width: width, height: ascent + descent)
            let origin = place(size, in: canvas, at: mark.position, margin: margin)

            // A soft shadow keeps white text readable on light photos.
            ctx.setShadow(offset: CGSize(width: 0, height: -fontSize * 0.04), blur: fontSize * 0.2,
                          color: CGColor(gray: 0, alpha: 0.6))
            ctx.textPosition = CGPoint(x: origin.x, y: origin.y + descent)
            CTLineDraw(line, ctx)
        }

        guard let result = ctx.makeImage() else { throw PicFacetError.customError("Failed to add watermark") }
        return result
    }

    /// Bottom-left origin of a box of `size` (CoreGraphics coordinates, y up).
    static func place(_ size: CGSize, in canvas: CGRect, at position: Watermark.Position, margin: CGFloat) -> CGPoint {
        let left = margin
        let right = canvas.width - margin - size.width
        let bottom = margin
        let top = canvas.height - margin - size.height
        switch position {
        case .topLeft: return CGPoint(x: left, y: top)
        case .topRight: return CGPoint(x: right, y: top)
        case .bottomLeft: return CGPoint(x: left, y: bottom)
        case .bottomRight: return CGPoint(x: right, y: bottom)
        case .center: return CGPoint(x: (canvas.width - size.width) / 2, y: (canvas.height - size.height) / 2)
        }
    }

    private static func loadLogo(_ path: String) throws -> CGImage {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw PicFacetError.customError("Can't read the watermark logo '\(url.lastPathComponent)'.")
        }
        return image
    }
}
