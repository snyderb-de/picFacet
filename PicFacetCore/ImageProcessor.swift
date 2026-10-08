import Foundation
import CoreGraphics
import ImageIO

/// What to do to every file in a batch. Any combination of steps may be set;
/// they are applied to each file in memory, in the order
/// crop → resize → watermark → metadata → DPI → encode (quality / target size),
/// and each output is written exactly once.
public struct BatchSelection: Hashable, Codable, Sendable {
    public var format: ImageFormat?
    public var resize: ResizeOperation?
    public var dpi: Int?
    /// Lossy compression quality, 1…100. Ignored by lossless formats.
    public var quality: Int?
    /// Target file size in bytes.
    public var maxBytes: Int?
    public var metadata: MetadataMode?
    public var crop: CropRatio?
    public var watermark: Watermark?
    public var rename: RenamePattern?

    public init(
        format: ImageFormat? = nil,
        resize: ResizeOperation? = nil,
        dpi: Int? = nil,
        quality: Int? = nil,
        maxBytes: Int? = nil,
        metadata: MetadataMode? = nil,
        crop: CropRatio? = nil,
        watermark: Watermark? = nil,
        rename: RenamePattern? = nil
    ) {
        self.format = format
        self.resize = resize
        self.dpi = dpi
        self.quality = quality
        self.maxBytes = maxBytes
        self.metadata = metadata
        self.crop = crop
        self.watermark = watermark
        self.rename = rename
    }

    public var hasSelection: Bool {
        needsEncode || renames
    }

    /// True when the pixels or metadata are rewritten. A rename alone only copies the file.
    var needsEncode: Bool {
        format != nil || resize != nil || dpi != nil || quality != nil || maxBytes != nil
            || metadata != nil || crop != nil || watermark?.isValid == true
    }

    var renames: Bool { rename.map { !$0.isEmpty } ?? false }

    /// True when the result's size depends on more than metadata, so
    /// "Keep result only if smaller" applies.
    var changesPixelsOrEncoding: Bool {
        format != nil || resize != nil || quality != nil || maxBytes != nil || crop != nil || watermark?.isValid == true
    }

    /// Pixel size of the saved image for a source of this size, after crop
    /// and resize (a target file size may shrink it further).
    public func outputPixelSize(width: Int, height: Int, proportional: Bool) -> (width: Int, height: Int) {
        guard width > 0, height > 0 else { return (width, height) }
        var w = width, h = height
        if let crop {
            let rect = CropEngine.rect(width: w, height: h, ratio: crop)
            w = Int(rect.width)
            h = Int(rect.height)
        }
        if let resize {
            let size = ResizeEngine.size(width: w, height: h, operation: resize, proportional: proportional)
            w = Int(size.width)
            h = Int(size.height)
        }
        return (w, h)
    }

    /// Human-readable steps, e.g. "Convert to PNG + Resize to 50% + Set 300 DPI".
    public var summary: String {
        var parts: [String] = []
        if let format { parts.append("Convert to \(format.displayName)") }
        if let crop { parts.append("Crop to \(crop.label)") }
        if let resize { parts.append(resize.displayName) }
        if let quality { parts.append("Quality \(quality)") }
        if let maxBytes { parts.append("Under \(formatBytes(maxBytes))") }
        if let dpi { parts.append("Set \(dpi) DPI") }
        if let metadata { parts.append(metadata.displayName) }
        if let watermark, watermark.isValid { parts.append(watermark.summary) }
        if let rename, !rename.isEmpty { parts.append("Rename to \(rename.template)") }
        return parts.joined(separator: " + ")
    }
}

/// Where and whether output is written. Callers snapshot it once per batch
/// (usually `PicFacetSettings.outputPolicy`) so a settings change mid-batch
/// cannot leak in, and tests pass plain values.
public struct OutputPolicy: Sendable {
    public var overwriteSource: Bool
    public var onlyIfSmaller: Bool
    public var deleteOriginalAfterConvert: Bool
    public var isProportional: Bool
    /// Sources PicFacet can read but not write (RAW, ICO, PSD…) have no
    /// "same format" to resize or re-tag into. When true they are saved as
    /// JPEG beside the original; when false such files fail with an
    /// explanation unless the run also picks a Convert format.
    public var saveUnsupportedAsJPEG: Bool
    /// nil = same folder as source
    public var customOutputFolder: URL?
    /// Permanently delete the source (bypassing the Trash) after any result is
    /// written elsewhere, not only after a format conversion. Watched folders only.
    public var deleteSourceAfterWrite: Bool

    public init(
        overwriteSource: Bool = false,
        onlyIfSmaller: Bool = false,
        deleteOriginalAfterConvert: Bool = false,
        isProportional: Bool = true,
        saveUnsupportedAsJPEG: Bool = false,
        customOutputFolder: URL? = nil,
        deleteSourceAfterWrite: Bool = false
    ) {
        self.overwriteSource = overwriteSource
        self.onlyIfSmaller = onlyIfSmaller
        self.deleteOriginalAfterConvert = deleteOriginalAfterConvert
        self.isProportional = isProportional
        self.saveUnsupportedAsJPEG = saveUnsupportedAsJPEG
        self.customOutputFolder = customOutputFolder
        self.deleteSourceAfterWrite = deleteSourceAfterWrite
    }
}

/// Runs a batch selection over a set of files. Max 4 files in flight.
public enum ImageProcessor {
    static let maxConcurrentFiles = 4
    /// Resolution PDF pages are rendered at when the run sets no DPI.
    static let defaultPDFDPI = 150

    /// Processes every URL and returns once all are done.
    /// `onProgress` runs on the main actor after each file.
    public static func process(
        _ urls: [URL],
        _ selection: BatchSelection,
        policy: OutputPolicy,
        onProgress: @escaping @MainActor @Sendable (BatchProgress) -> Void = { _ in }
    ) async -> ProcessingResult {
        var reports: [FileReport] = []
        // Fixed once so {n} in a rename pattern follows the order given.
        let batchDate = Date()

        await withTaskGroup(of: FileReport.self) { group in
            var pending = urls.enumerated().makeIterator()

            func addNext() -> Bool {
                guard let (index, url) = pending.next() else { return false }
                group.addTask(priority: .userInitiated) {
                    do {
                        return try processFile(url, selection, policy: policy,
                                               index: index, count: urls.count, date: batchDate)
                    } catch {
                        return FileReport(source: url, outcome: .failed(error))
                    }
                }
                return true
            }

            for _ in 0..<maxConcurrentFiles where !addNext() { break }

            for await report in group {
                reports.append(report)
                await onProgress(BatchProgress(completed: reports.count, total: urls.count, latest: report))
                _ = addNext()
            }
        }

        return ProcessingResult(reports: reports)
    }

    /// Applies every selected step to one file and writes it once
    /// (once per page for a PDF).
    static func processFile(
        _ url: URL, _ selection: BatchSelection, policy: OutputPolicy,
        index: Int = 0, count: Int = 1, date: Date = Date()
    ) throws -> FileReport {
        // Finder-vended URLs may be security scoped
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let originalBytes = FileOutputManager.fileSize(url)
        let sourceName = url.deletingPathExtension().lastPathComponent

        guard selection.needsEncode else {
            return try renameOnly(url, selection, policy: policy, index: index, count: count, date: date)
        }

        // Sources PicFacet can't write (RAW, ICO…, and PDF, which would only be
        // rasterised) have no same-format output. With the policy on they are
        // saved as JPEG beside the original, which is never overwritten or
        // deleted unless a Convert target was chosen.
        let isPDF = url.isPDFFile
        let sourceFormat = isPDF ? nil : ImageFormat(fileExtension: url.pathExtension)
        if sourceFormat == nil && selection.format == nil && !policy.saveUnsupportedAsJPEG {
            throw PicFacetError.customError(isPDF
                ? "Choose a Convert format to turn PDF pages into images."
                : "PicFacet can't write .\(url.pathExtension.lowercased()) files. Choose a Convert format, or turn on “Save unsupported formats as JPEG” in Settings.")
        }
        let targetFormat = selection.format ?? sourceFormat ?? .jpeg
        let changesFormat = selection.format != nil || sourceFormat == nil

        // Decode: one frame for an image, one per page for a PDF.
        var frames: [CGImage]
        var properties: [String: Any]
        if isPDF {
            let dpi = selection.dpi ?? defaultPDFDPI
            frames = try ConversionEngine.readPDFPages(from: url, dpi: dpi)
            properties = DPIEngine.updatedProperties([:], dpi: dpi, for: targetFormat)
        } else {
            let (image, props) = try ConversionEngine.readImage(from: url)
            frames = [image]
            properties = props
        }

        if let metadata = selection.metadata {
            properties = MetadataEngine.strip(metadata, from: properties)
        }
        if let dpi = selection.dpi {
            properties = DPIEngine.updatedProperties(properties, dpi: dpi, for: targetFormat)
        }

        var staged: [(file: URL, output: URL)] = []
        defer { for item in staged { try? FileManager.default.removeItem(at: item.file) } }
        var resultBytes = 0
        var missedTarget = false

        for (page, frame) in frames.enumerated() {
            var image = frame
            if let crop = selection.crop {
                image = try CropEngine.crop(image, to: crop)
            }
            if let resize = selection.resize {
                let newSize = ResizeEngine.size(for: image, operation: resize, proportional: policy.isProportional)
                if Int(newSize.width) != image.width || Int(newSize.height) != image.height {
                    image = try ResizeEngine.resize(image, toSize: newSize)
                }
            }
            if let watermark = selection.watermark, watermark.isValid {
                image = try WatermarkEngine.apply(watermark, to: image)
            }

            let quality = selection.quality.map { Double($0) / 100 }
            let data: Data
            if let maxBytes = selection.maxBytes {
                let fitted = try TargetSizeEncoder.encode(image, properties: properties, format: targetFormat,
                                                          maxBytes: maxBytes, startQuality: quality)
                data = fitted.data
                image = fitted.image
                missedTarget = missedTarget || !fitted.reachedTarget
            } else {
                data = try ConversionEngine.encode(image, properties: properties, format: targetFormat, quality: quality)
            }

            var baseName = selection.rename.flatMap { pattern -> String? in
                guard !pattern.isEmpty else { return nil }
                return pattern.apply(.init(name: sourceName, index: index, count: count,
                                           width: image.width, height: image.height,
                                           fileExtension: targetFormat.fileExtension, date: date))
            }
            if frames.count > 1 {
                baseName = "\(baseName ?? sourceName)-p\(page + 1)"
            }

            let output = changesFormat
                ? FileOutputManager.outputURL(for: url, targetFormat: targetFormat, baseName: baseName, policy: policy)
                : FileOutputManager.outputURL(for: url, baseName: baseName, policy: policy)

            // Write beside the output first: the source must survive until the
            // size check passes, even when the output replaces it.
            let file = FileOutputManager.stagingURL(for: output)
            do { try data.write(to: file) } catch { throw PicFacetError.writeFailed(output) }
            staged.append((file, output))
            resultBytes += data.count
        }

        // Metadata-only edits (DPI, stripping) aren't about size, so the size rule does not apply.
        if policy.onlyIfSmaller && selection.changesPixelsOrEncoding && resultBytes >= originalBytes {
            return FileReport(source: url, outcome: .keptOriginal,
                              originalBytes: originalBytes, resultBytes: resultBytes)
        }

        for item in staged {
            try FileOutputManager.commit(item.file, to: item.output)
        }
        let outputs = staged.map(\.output)
        staged.removeAll()

        if !outputs.contains(where: { $0.path == url.path }) {
            if policy.deleteSourceAfterWrite {
                try? FileManager.default.removeItem(at: url)
            } else if selection.format != nil {
                FileOutputManager.deleteOriginal(url, policy: policy)
            }
        }
        let note = missedTarget
            ? "Couldn't get under \(formatBytes(selection.maxBytes ?? 0)); saved the smallest version."
            : nil
        return FileReport(source: url, outcome: .written(outputs[0]),
                          originalBytes: originalBytes, resultBytes: resultBytes,
                          extraOutputs: Array(outputs.dropFirst()), note: note)
    }

    /// A rename with no other step copies the file under its new name, byte
    /// for byte. "Overwrite source" or "Delete original" make it a move.
    private static func renameOnly(
        _ url: URL, _ selection: BatchSelection, policy: OutputPolicy, index: Int, count: Int, date: Date
    ) throws -> FileReport {
        let originalBytes = FileOutputManager.fileSize(url)
        guard let pattern = selection.rename, !pattern.isEmpty else {
            return FileReport(source: url, outcome: .keptOriginal, originalBytes: originalBytes)
        }
        let header = ImageHeader.read(url)
        let baseName = pattern.apply(.init(name: url.deletingPathExtension().lastPathComponent,
                                           index: index, count: count,
                                           width: header.width, height: header.height,
                                           fileExtension: url.pathExtension.lowercased(), date: date))
        let output = FileOutputManager.outputURL(for: url, baseName: baseName,
                                                 policy: OutputPolicy(customOutputFolder: policy.customOutputFolder))
        guard output.path != url.path else {
            return FileReport(source: url, outcome: .keptOriginal, originalBytes: originalBytes)
        }

        let move = policy.overwriteSource || policy.deleteOriginalAfterConvert || policy.deleteSourceAfterWrite
        let staged = FileOutputManager.stagingURL(for: output)
        defer { try? FileManager.default.removeItem(at: staged) }
        do { try FileManager.default.copyItem(at: url, to: staged) } catch { throw PicFacetError.writeFailed(output) }
        try FileOutputManager.commit(staged, to: output)
        if move { try? FileManager.default.removeItem(at: url) }

        return FileReport(source: url, outcome: .written(output),
                          originalBytes: originalBytes, resultBytes: originalBytes)
    }
}

/// Pixel size from the file header, without decoding.
enum ImageHeader {
    static func read(_ url: URL) -> (width: Int, height: Int) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (0, 0)
        }
        let width = (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        return (width, height)
    }
}

// MARK: - Service commands

public extension BatchSelection {
    /// Parses the `NSUserData` string of a Finder service entry.
    ///
    /// Steps are separated by `;` and may be combined:
    /// `convert:<format>`, `resize:<n>%`, `width:<n>`, `height:<n>`,
    /// `longedge:<n>`, `dpi:<n>`, `quality:<1-100>`, `target:<n>kb|mb`,
    /// `metadata:location|all`, `crop:<w>:<h>`.
    /// Example: `convert:png;resize:50%;dpi:300`. Returns nil when any step is
    /// malformed or nothing is selected.
    init?(serviceCommand: String) {
        var selection = BatchSelection()
        for step in serviceCommand.split(separator: ";") {
            let parts = step.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2 else { return nil }
            let (verb, value) = (parts[0].lowercased(), parts[1])

            func positive(_ text: String) -> Int? {
                guard let n = Int(text), n > 0 else { return nil }
                return n
            }

            switch verb {
            case "convert":
                guard let format = ImageFormat(fileExtension: value) else { return nil }
                selection.format = format
            case "resize":
                guard value.hasSuffix("%"), let n = positive(String(value.dropLast())) else { return nil }
                selection.resize = .percent(n)
            case "width":
                guard let n = positive(value) else { return nil }
                selection.resize = .width(n)
            case "height":
                guard let n = positive(value) else { return nil }
                selection.resize = .height(n)
            case "longedge":
                guard let n = positive(value) else { return nil }
                selection.resize = .longEdge(n)
            case "dpi":
                guard let n = positive(value) else { return nil }
                selection.dpi = n
            case "quality":
                guard let n = positive(value), n <= 100 else { return nil }
                selection.quality = n
            case "target":
                let lower = value.lowercased()
                let units: [(suffix: String, bytes: Int)] = [("kb", 1_000), ("mb", 1_000_000)]
                guard let unit = units.first(where: { lower.hasSuffix($0.suffix) }),
                      let n = positive(String(lower.dropLast(2)).trimmingCharacters(in: .whitespaces)) else { return nil }
                selection.maxBytes = n * unit.bytes
            case "metadata":
                guard let mode = MetadataMode(rawValue: value.lowercased()) else { return nil }
                selection.metadata = mode
            case "crop":
                guard let ratio = CropRatio(label: value) else { return nil }
                selection.crop = ratio
            default:
                return nil
            }
        }
        guard selection.hasSelection else { return nil }
        self = selection
    }
}
