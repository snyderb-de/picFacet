import Foundation
import CoreGraphics

/// Centre crop to an aspect ratio. Keeps as many pixels as the ratio allows.
enum CropEngine {
    static func crop(_ image: CGImage, to ratio: CropRatio) throws -> CGImage {
        let rect = rect(width: image.width, height: image.height, ratio: ratio)
        guard rect.width != CGFloat(image.width) || rect.height != CGFloat(image.height) else { return image }
        guard let cropped = image.cropping(to: rect) else { throw PicFacetError.customError("Failed to crop image") }
        return cropped
    }

    static func rect(width: Int, height: Int, ratio: CropRatio) -> CGRect {
        let target = Double(ratio.width) / Double(ratio.height)
        let w = Double(width), h = Double(height)
        var cropW = w, cropH = h
        if w / h > target {
            cropW = max(1, (h * target).rounded())
        } else {
            cropH = max(1, (w / target).rounded())
        }
        return CGRect(x: ((w - cropW) / 2).rounded(.down), y: ((h - cropH) / 2).rounded(.down),
                      width: cropW, height: cropH)
    }
}
