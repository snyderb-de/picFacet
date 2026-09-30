import Foundation
import CoreGraphics

/// What to do to every file in a batch. Any combination of steps may be set;
/// they are applied to each file in memory, in the order convert → resize → DPI,
/// and the file is written exactly once.
public struct BatchSelection: Hashable, Sendable {
    public var format: ImageFormat?
    public var resize: ResizeOperation?
    public var dpi: Int?

    public init(format: ImageFormat? = nil, resize: ResizeOperation? = nil, dpi: Int? = nil) {
        self.format = format
        self.resize = resize
        self.dpi = dpi
    }

    public var hasSelection: Bool {
        format != nil || resize != nil || dpi != nil
    }

    /// Human-readable steps, e.g. "Convert to PNG + Resize to 50% + Set 300 DPI".
    public var summary: String {
        var parts: [String] = []
        if let format { parts.append("Convert to \(format.displayName)") }
        if let resize { parts.append(resize.displayName) }
        if let dpi { parts.append("Set \(dpi) DPI") }
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
    /// nil = same folder as source
    public var customOutputFolder: URL?

    public init(
        overwriteSource: Bool = false,
        onlyIfSmaller: Bool = false,
        deleteOriginalAfterConvert: Bool = false,
        isProportional: Bool = true,
        customOutputFolder: URL? = nil
    ) {
        self.overwriteSource = overwriteSource
        self.onlyIfSmaller = onlyIfSmaller
        self.deleteOriginalAfterConvert = deleteOriginalAfterConvert
        self.isProportional = isProportional
        self.customOutputFolder = customOutputFolder
    }
}

/// Runs a batch selection over a set of files. Max 4 files in flight.
public enum ImageProcessor {
    static let maxConcurrentFiles = 4

    /// Processes every URL and returns once all are done.
    /// `onProgress` runs on the main actor after each file.
    public static func process(
        _ urls: [URL],
        _ selection: BatchSelection,
        policy: OutputPolicy,
        onProgress: @escaping @MainActor @Sendable (BatchProgress) -> Void = { _ in }
    ) async -> ProcessingResult {
        var reports: [FileReport] = []

        await withTaskGroup(of: FileReport.self) { group in
            var pending = urls.makeIterator()

            func addNext() -> Bool {
                guard let url = pending.next() else { return false }
                group.addTask(priority: .userInitiated) {
                    do {
                        return try processFile(url, selection, policy: policy)
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

    /// Applies every selected step to one file and writes it once.
    static func processFile(_ url: URL, _ selection: BatchSelection, policy: OutputPolicy) throws -> FileReport {
        // Finder-vended URLs may be security scoped
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        let originalBytes = FileOutputManager.fileSize(url)
        var (image, properties) = try ConversionEngine.readImage(from: url)
        let targetFormat = selection.format ?? ImageFormat(fileExtension: url.pathExtension) ?? .jpeg
        var needsWrite = selection.format != nil

        if let resize = selection.resize {
            let newSize = ResizeEngine.size(for: image, operation: resize, proportional: policy.isProportional)
            image = try ResizeEngine.resize(image, toSize: newSize)
            needsWrite = true
        }

        if let dpi = selection.dpi {
            properties = DPIEngine.updatedProperties(properties, dpi: dpi, for: targetFormat)
            needsWrite = true
        }

        guard needsWrite else {
            return FileReport(source: url, outcome: .keptOriginal, originalBytes: originalBytes)
        }

        let output = selection.format.map {
            FileOutputManager.outputURL(for: url, targetFormat: $0, policy: policy)
        } ?? FileOutputManager.outputURL(for: url, policy: policy)

        // Write beside the output first: the source must survive until the
        // size check passes, even when the output replaces it.
        let staged = FileOutputManager.stagingURL(for: output)
        defer { try? FileManager.default.removeItem(at: staged) }
        try ConversionEngine.writeImage(image, properties: properties, to: staged, format: targetFormat)
        let resultBytes = FileOutputManager.fileSize(staged)

        // DPI-only edits are metadata changes, so the size rule does not apply.
        let changesPixelsOrFormat = selection.format != nil || selection.resize != nil
        if policy.onlyIfSmaller && changesPixelsOrFormat && resultBytes >= originalBytes {
            return FileReport(source: url, outcome: .keptOriginal,
                              originalBytes: originalBytes, resultBytes: resultBytes)
        }

        try FileOutputManager.commit(staged, to: output)

        if selection.format != nil && output.path != url.path {
            FileOutputManager.deleteOriginal(url, policy: policy)
        }
        return FileReport(source: url, outcome: .written(output),
                          originalBytes: originalBytes, resultBytes: resultBytes)
    }
}

// MARK: - Service commands

public extension BatchSelection {
    /// Parses the `NSUserData` string of a Finder service entry.
    ///
    /// Steps are separated by `;` and may be combined:
    /// `convert:<format>`, `resize:<n>%`, `width:<n>`, `height:<n>`, `dpi:<n>`.
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
            case "dpi":
                guard let n = positive(value) else { return nil }
                selection.dpi = n
            default:
                return nil
            }
        }
        guard selection.hasSelection else { return nil }
        self = selection
    }
}
