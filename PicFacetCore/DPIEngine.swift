import Foundation
import ImageIO

/// Patches an ImageIO properties dictionary with the requested DPI,
/// using the correct format-specific metadata keys for each image type.
struct DPIEngine {

    static func updatedProperties(
        _ properties: [String: Any],
        dpi: Int,
        for format: ImageFormat
    ) -> [String: Any] {
        var props = properties

        switch format {

        case .jpeg:
            var jfif = props[kCGImagePropertyJFIFDictionary as String] as? [String: Any] ?? [:]
            jfif[kCGImagePropertyJFIFXDensity as String] = dpi
            jfif[kCGImagePropertyJFIFYDensity as String] = dpi
            jfif[kCGImagePropertyJFIFDensityUnit as String] = 1 // 1 = pixels per inch
            props[kCGImagePropertyJFIFDictionary as String] = jfif

        case .png:
            // PNG stores resolution in pixels per metre
            let ppm = Int((Double(dpi) * 10000.0 / 254.0).rounded())
            var png = props[kCGImagePropertyPNGDictionary as String] as? [String: Any] ?? [:]
            png[kCGImagePropertyPNGXPixelsPerMeter as String] = ppm
            png[kCGImagePropertyPNGYPixelsPerMeter as String] = ppm
            props[kCGImagePropertyPNGDictionary as String] = png

        case .tiff:
            var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiff[kCGImagePropertyTIFFXResolution as String] = dpi
            tiff[kCGImagePropertyTIFFYResolution as String] = dpi
            tiff[kCGImagePropertyTIFFResolutionUnit as String] = 2 // 2 = inch
            props[kCGImagePropertyTIFFDictionary as String] = tiff

        default:
            // For WebP, HEIC, GIF, BMP — write TIFF-style resolution tags.
            // ImageIO will embed what it can for each format.
            var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] ?? [:]
            tiff[kCGImagePropertyTIFFXResolution as String] = dpi
            tiff[kCGImagePropertyTIFFYResolution as String] = dpi
            tiff[kCGImagePropertyTIFFResolutionUnit as String] = 2
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }

        return props
    }
}
