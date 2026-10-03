import AppKit
import ImageIO
import SwiftUI
import PicFacetCore

/// What the queue shows about one file, read from the header only (no full decode).
struct ImageInfo: Sendable {
    var pixelWidth: Int?
    var pixelHeight: Int?
    var dpi: Int?
    var bytes: Int64?

    /// "4032 × 3024 px", or nil when ImageIO can't tell.
    var dimensions: String? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return "\(pixelWidth) × \(pixelHeight) px"
    }

    /// "2.1 MB · 72 DPI"; each half is dropped when unknown.
    var sizeAndDPI: String? {
        var parts: [String] = []
        if let bytes { parts.append(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)) }
        if let dpi { parts.append("\(dpi) DPI") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func load(_ url: URL) async -> ImageInfo {
        await Task.detached(priority: .utility) { read(url) }.value
    }

    nonisolated private static func read(_ url: URL) -> ImageInfo {
        var info = ImageInfo()
        info.bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return info
        }
        info.pixelWidth = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue
        info.pixelHeight = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue
        if let dpi = (props[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue, dpi > 0 {
            info.dpi = Int(dpi.rounded())
        }
        return info
    }
}

/// One queue entry: thumbnail plus three lines.
///   1. File name with its extension
///   2. Pixel dimensions
///   3. File size · DPI
/// Used by both the Chooser and the Batch window so the queue reads the same
/// everywhere, whatever mix of formats is in it.
struct ImageQueueRow: View {
    let url: URL
    var thumbnailSize: CGFloat = 52

    @State private var thumbnail: NSImage?
    @State private var info: ImageInfo?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(PFDesign.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(info?.dimensions ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .lineLimit(1)

                Text(info?.sizeAndDPI ?? " ")
                    .font(.system(size: 11))
                    .foregroundStyle(PFDesign.onSurfaceVariant)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(9)
        .background(PFDesign.surfaceLow, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PFDesign.outlineVariant.opacity(0.12), lineWidth: 1)
        }
        .task(id: url) {
            async let loadedInfo = ImageInfo.load(url)
            async let loadedThumb = Thumbnail.load(url, maxPixelSize: Int(thumbnailSize * 2))
            info = await loadedInfo
            thumbnail = await loadedThumb
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Group {
            if let thumbnail {
                Color.clear.overlay {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fill)
                }
            } else {
                PFDesign.surfaceLowest.overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 14))
                        .foregroundStyle(PFDesign.onSurfaceVariant.opacity(0.5))
                }
            }
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .clipShape(shape)
        .overlay { shape.strokeBorder(PFDesign.outlineVariant.opacity(0.2), lineWidth: 1) }
    }
}
