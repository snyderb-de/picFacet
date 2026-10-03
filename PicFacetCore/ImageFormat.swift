import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Sendable {
    case jpeg
    case png
    case webp
    case tiff
    case gif
    case bmp
    case heic

    public var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png:  return "PNG"
        case .webp: return "WebP"
        case .tiff: return "TIFF"
        case .gif:  return "GIF"
        case .bmp:  return "BMP"
        case .heic: return "HEIC"
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .tiff: return "tif"
        default:    return rawValue
        }
    }

    /// UTI string used by ImageIO when writing.
    public var utiString: String {
        switch self {
        case .jpeg: return "public.jpeg"
        case .png:  return "public.png"
        case .webp: return "org.webmproject.webp"
        case .tiff: return "public.tiff"
        case .gif:  return "com.compuserve.gif"
        case .bmp:  return "com.microsoft.bmp"
        case .heic: return "public.heic"
        }
    }

    /// Initialise from a file extension (case-insensitive).
    public init?(fileExtension ext: String) {
        switch ext.lowercased() {
        case "jpg", "jpeg": self = .jpeg
        case "png":         self = .png
        case "webp":        self = .webp
        case "tif", "tiff": self = .tiff
        case "gif":         self = .gif
        case "bmp":         self = .bmp
        case "heic", "heif":self = .heic
        default:            return nil
        }
    }
}

// MARK: - URL helpers

public extension URL {
    /// True if ImageIO can read this file type: the seven formats PicFacet writes
    /// plus anything else the system decodes (RAW, AVIF, JPEG 2000, ICO, PSD…).
    /// Decided from the extension only, so it is cheap to call on every drop.
    var isImageFile: Bool {
        if ImageFormat(fileExtension: pathExtension) != nil { return true }
        guard !pathExtension.isEmpty,
              let type = UTType(filenameExtension: pathExtension) else { return false }
        return ImageReadableTypes.all.contains { type.conforms(to: $0) }
    }
}

/// The types ImageIO can decode on this Mac, so unreadable "images" such as
/// SVG (which conforms to public.image) are not accepted.
private enum ImageReadableTypes {
    static let all: [UTType] = {
        let ids = (CGImageSourceCopyTypeIdentifiers() as? [String]) ?? []
        return ids.compactMap { UTType($0) }
    }()
}
