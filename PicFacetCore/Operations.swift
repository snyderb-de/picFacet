import Foundation

// Value types for the optional pipeline steps beyond convert / resize / DPI.
// All are Codable so a `BatchSelection` can be saved as a recipe.

/// Which metadata to remove from the output.
public enum MetadataMode: String, CaseIterable, Codable, Hashable, Sendable {
    /// GPS coordinates and IPTC place names. Camera and date info stay.
    case location
    /// Everything except DPI and orientation.
    case all

    public var displayName: String {
        switch self {
        case .location: return "Remove location"
        case .all: return "Remove all metadata"
        }
    }
}

/// Centre crop to an aspect ratio, applied before resizing.
public struct CropRatio: Codable, Hashable, Sendable {
    public var width: Int
    public var height: Int

    public init(_ width: Int, _ height: Int) {
        self.width = width
        self.height = height
    }

    public static let presets: [CropRatio] = [
        CropRatio(1, 1), CropRatio(4, 5), CropRatio(3, 2), CropRatio(4, 3), CropRatio(16, 9), CropRatio(9, 16)
    ]

    /// "16:9"
    public var label: String { "\(width):\(height)" }

    /// Parses "16:9". Nil unless both sides are positive.
    public init?(label: String) {
        let parts = label.split(separator: ":").map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard parts.count == 2, let w = parts[0], let h = parts[1], w > 0, h > 0 else { return nil }
        self.init(w, h)
    }
}

/// Text or logo stamped onto every image after resizing.
public struct Watermark: Codable, Hashable, Sendable {
    public enum Position: String, CaseIterable, Codable, Sendable {
        case topLeft, topRight, center, bottomLeft, bottomRight

        public var displayName: String {
            switch self {
            case .topLeft: return "Top left"
            case .topRight: return "Top right"
            case .center: return "Centre"
            case .bottomLeft: return "Bottom left"
            case .bottomRight: return "Bottom right"
            }
        }
    }

    public enum Size: String, CaseIterable, Codable, Sendable {
        case small, medium, large

        public var displayName: String { rawValue.capitalized }

        /// Multiplier on the base mark size (a share of the image's short side).
        var scale: Double {
            switch self {
            case .small: return 0.6
            case .medium: return 1
            case .large: return 1.6
            }
        }
    }

    /// Drawn when `logoPath` is nil.
    public var text: String
    /// PNG with transparency works best.
    public var logoPath: String?
    public var position: Position
    public var size: Size
    /// 0…1
    public var opacity: Double

    public init(text: String = "", logoPath: String? = nil, position: Position = .bottomRight,
                size: Size = .medium, opacity: Double = 0.75) {
        self.text = text
        self.logoPath = logoPath
        self.position = position
        self.size = size
        self.opacity = opacity
    }

    /// False for a text mark with no text, which would draw nothing.
    public var isValid: Bool {
        logoPath != nil || !text.trimmingCharacters(in: .whitespaces).isEmpty
    }

    public var summary: String {
        if let logoPath { return "Watermark \(URL(fileURLWithPath: logoPath).lastPathComponent)" }
        return "Watermark “\(text)”"
    }
}

/// Output file name template. Tokens:
/// `{name}` source name, `{n}` position in the batch (zero-padded),
/// `{date}` today as yyyy-MM-dd, `{width}` / `{height}` output pixels,
/// `{format}` output format, e.g. "jpg".
public struct RenamePattern: Codable, Hashable, Sendable {
    public var template: String

    public init(_ template: String) {
        self.template = template
    }

    public static let tokens = ["{name}", "{n}", "{date}", "{width}", "{height}", "{format}"]

    public var isEmpty: Bool { template.trimmingCharacters(in: .whitespaces).isEmpty }

    public struct Context: Sendable {
        public var name: String
        public var index: Int
        public var count: Int
        public var width: Int
        public var height: Int
        /// Output extension without the dot, e.g. "jpg".
        public var fileExtension: String
        public var date: Date

        public init(name: String, index: Int, count: Int, width: Int, height: Int,
                    fileExtension: String, date: Date = Date()) {
            self.name = name
            self.index = index
            self.count = count
            self.width = width
            self.height = height
            self.fileExtension = fileExtension
            self.date = date
        }
    }

    /// The base name (no extension). Falls back to the source name when the
    /// template renders empty. Path separators are replaced so the result is
    /// always a single file name.
    public func apply(_ c: Context) -> String {
        let digits = max(2, String(c.count).count)
        let number = String(c.index + 1)
        let padded = String(repeating: "0", count: max(0, digits - number.count)) + number

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var out = template
        let values: [(String, String)] = [
            ("{name}", c.name),
            ("{n}", padded),
            ("{date}", formatter.string(from: c.date)),
            ("{width}", String(c.width)),
            ("{height}", String(c.height)),
            ("{format}", c.fileExtension)
        ]
        for (token, value) in values {
            out = out.replacingOccurrences(of: token, with: value)
        }
        out = out.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading dot would hide the file; staging files use that prefix.
        while out.hasPrefix(".") { out.removeFirst() }
        return out.isEmpty ? c.name : out
    }
}

/// Human-readable byte count for summaries, e.g. "500 KB".
public func formatBytes(_ bytes: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}
