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

    /// Blocking variant for callers already off the main actor.
    nonisolated static func load(readingSync url: URL) -> ImageInfo { read(url) }

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
    @State private var hoverTask: Task<Void, Never>?
    @State private var showPreview = false
    @State private var preview: NSImage?

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
        .onHover { inside in
            hoverTask?.cancel()
            guard inside else { showPreview = false; return }
            // Short delay so sweeping the mouse down the list doesn't flash popovers.
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                if preview == nil { preview = await Thumbnail.load(url, maxPixelSize: 900) }
                if !Task.isCancelled { showPreview = preview != nil }
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .trailing) {
            if let preview {
                Image(nsImage: preview)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 420)
                    .padding(8)
            }
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


// MARK: - Queue summary

/// Totals for the whole queue, read from file headers.
struct QueueSummary: Sendable {
    var count = 0
    var bytes: Int64 = 0
    var pixels: Int64 = 0
    var formats: [String: Int] = [:]

    var sizeText: String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }

    /// "42.3 MP", or "—" before the headers are read.
    var megapixelsText: String {
        pixels > 0 ? String(format: "%.1f MP", Double(pixels) / 1_000_000) : "—"
    }

    /// "7 types" for the stat pill (the breakdown is in `formatsDetail`).
    var formatsText: String {
        formats.isEmpty ? "—" : "\(formats.count) type\(formats.count == 1 ? "" : "s")"
    }

    /// Tooltip: most common first, "JPG 8 · PNG 2 · HEIC 1".
    var formatsDetail: String {
        formats.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map { "\($0.key) \($0.value)" }.joined(separator: " · ")
    }

    static func load(_ urls: [URL]) async -> QueueSummary {
        await Task.detached(priority: .utility) {
            var summary = QueueSummary()
            for url in urls {
                let info = ImageInfo.load(readingSync: url)
                summary.count += 1
                summary.bytes += info.bytes ?? 0
                if let w = info.pixelWidth, let h = info.pixelHeight { summary.pixels += Int64(w) * Int64(h) }
                let ext = url.pathExtension.uppercased()
                summary.formats[ext.isEmpty ? "?" : ext, default: 0] += 1
            }
            return summary
        }.value
    }
}

/// Running totals for a batch, built from per-file reports as they finish.
struct RunStats {
    var done = 0
    var total = 0
    var bytesBefore: Int64 = 0
    var bytesAfter: Int64 = 0
    var kept = 0
    var failed = 0

    mutating func add(_ report: FileReport) {
        done += 1
        switch report.outcome {
        case .written:
            bytesBefore += Int64(report.originalBytes ?? 0)
            bytesAfter += Int64(report.resultBytes ?? 0)
        case .keptOriginal: kept += 1
        case .failed: failed += 1
        }
    }

    var doneText: String { "\(done) of \(total)" }

    /// Label for the "Saved" pill, with the percentage once something is written.
    var savedTitle: String {
        guard bytesBefore > 0, bytesBefore > bytesAfter else { return "Saved" }
        let percent = Int((Double(bytesBefore - bytesAfter) / Double(bytesBefore) * 100).rounded())
        return "Saved · \(percent)%"
    }

    /// Bytes saved so far, "—" until something is written, "+x larger" if output grew.
    var savedText: String {
        guard bytesBefore > 0 else { return "—" }
        let saved = bytesBefore - bytesAfter
        let size = ByteCountFormatter.string(fromByteCount: abs(saved), countStyle: .file)
        return saved >= 0 ? size : "+\(size)"
    }
}
