import Foundation
import ImageIO

/// Edits an ImageIO properties dictionary. ImageIO writes only the metadata
/// passed to it, so removing a dictionary here removes it from the output.
enum MetadataEngine {

    static func strip(_ mode: MetadataMode, from properties: [String: Any]) -> [String: Any] {
        switch mode {
        case .location:
            var props = properties
            props.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
            if var iptc = props[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
                for key in iptcPlaceKeys { iptc.removeValue(forKey: key) }
                props[kCGImagePropertyIPTCDictionary as String] = iptc
            }
            return props

        case .all:
            // DPI is layout, not personal data; orientation keeps the image upright.
            let keep = [kCGImagePropertyDPIWidth, kCGImagePropertyDPIHeight, kCGImagePropertyOrientation]
                .map { $0 as String }
            return properties.filter { keep.contains($0.key) }
        }
    }

    /// Marks the pixels as already upright, at the top level and in TIFF.
    static func resettingOrientation(_ properties: [String: Any]) -> [String: Any] {
        var props = properties
        props[kCGImagePropertyOrientation as String] = 1
        if var tiff = props[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            tiff[kCGImagePropertyTIFFOrientation as String] = 1
            props[kCGImagePropertyTIFFDictionary as String] = tiff
        }
        return props
    }

    /// Keeps EXIF's pixel dimensions in step with a crop or resize.
    static func updatingPixelSize(_ properties: [String: Any], width: Int, height: Int) -> [String: Any] {
        guard var exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return properties
        }
        var props = properties
        exif[kCGImagePropertyExifPixelXDimension as String] = width
        exif[kCGImagePropertyExifPixelYDimension as String] = height
        props[kCGImagePropertyExifDictionary as String] = exif
        return props
    }

    private static let iptcPlaceKeys: [String] = [
        kCGImagePropertyIPTCCity,
        kCGImagePropertyIPTCSubLocation,
        kCGImagePropertyIPTCProvinceState,
        kCGImagePropertyIPTCCountryPrimaryLocationCode,
        kCGImagePropertyIPTCCountryPrimaryLocationName,
        kCGImagePropertyIPTCContactInfoAddress,
        kCGImagePropertyIPTCContactInfoCity,
        kCGImagePropertyIPTCContactInfoStateProvince,
        kCGImagePropertyIPTCContactInfoPostalCode,
        kCGImagePropertyIPTCContactInfoCountry
    ].map { $0 as String }
}
