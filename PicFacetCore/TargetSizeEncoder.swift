import Foundation
import CoreGraphics

/// Encodes an image to fit a byte budget. Lossy formats search compression
/// quality first; when even the lowest quality is too big, or the format is
/// lossless, the image is scaled down and tried again.
enum TargetSizeEncoder {
    struct Result {
        let data: Data
        /// The image that was encoded, smaller than the input if it had to shrink.
        let image: CGImage
        let reachedTarget: Bool
    }

    static let lowestQuality = 0.05
    static let qualitySteps = 7
    static let maxDownscales = 8

    /// - Parameter startQuality: Highest quality to try (0…1); defaults to 0.9.
    static func encode(
        _ image: CGImage,
        properties: [String: Any],
        format: ImageFormat,
        maxBytes: Int,
        startQuality: Double? = nil
    ) throws -> Result {
        var current = image
        var smallest: (data: Data, image: CGImage)?

        for _ in 0...maxDownscales {
            let attempt = try fit(current, properties: properties, format: format,
                                  maxBytes: maxBytes, startQuality: startQuality ?? 0.9)
            if attempt.fits { return Result(data: attempt.data, image: current, reachedTarget: true) }
            if smallest == nil || attempt.data.count < smallest!.data.count {
                smallest = (attempt.data, current)
            }

            // Bytes scale roughly with pixel count, so shrink each side by the
            // square root of the overshoot, a little extra, within sane bounds.
            let overshoot = Double(maxBytes) / Double(attempt.data.count)
            let factor = min(0.9, max(0.5, overshoot.squareRoot() * 0.95))
            let size = CGSize(width: (Double(current.width) * factor).rounded(.down),
                              height: (Double(current.height) * factor).rounded(.down))
            guard size.width >= 16, size.height >= 16 else { break }
            current = try ResizeEngine.resize(current, toSize: size)
        }

        let best = smallest!
        return Result(data: best.data, image: best.image, reachedTarget: false)
    }

    /// The best-quality encoding at the current size that fits, else the smallest one.
    private static func fit(
        _ image: CGImage, properties: [String: Any], format: ImageFormat, maxBytes: Int, startQuality: Double
    ) throws -> (data: Data, fits: Bool) {
        guard format.isLossy else {
            let data = try ConversionEngine.encode(image, properties: properties, format: format)
            return (data, data.count <= maxBytes)
        }

        let top = try ConversionEngine.encode(image, properties: properties, format: format, quality: startQuality)
        if top.count <= maxBytes { return (top, true) }

        let bottom = try ConversionEngine.encode(image, properties: properties, format: format, quality: lowestQuality)
        if bottom.count > maxBytes { return (bottom, false) }

        var low = lowestQuality, high = startQuality, best = bottom
        for _ in 0..<qualitySteps {
            let mid = (low + high) / 2
            let data = try ConversionEngine.encode(image, properties: properties, format: format, quality: mid)
            if data.count <= maxBytes {
                best = data
                low = mid
            } else {
                high = mid
            }
        }
        return (best, true)
    }
}
