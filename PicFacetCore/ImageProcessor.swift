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
}

/// Snapshot of the user settings that decide where and whether output is written.
/// Captured once per batch so a settings change mid-batch cannot leak in.
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

    public static var current: OutputPolicy {
        let settings = PicFacetSettings.shared
        return OutputPolicy(
            overwriteSource: settings.overwriteSource,
            onlyIfSmaller: settings.onlyIfSmaller,
            deleteOriginalAfterConvert: settings.deleteOriginalAfterConvert,
            isProportional: settings.isProportional,
            customOutputFolder: settings.customOutputFolder.map { URL(fileURLWithPath: $0) }
        )
    }
}

/// Runs a batch selection over a set of files. Max 4 files in flight.
public enum ImageProcessor {
    static let maxConcurrentFiles = 4

    /// Processes every URL and returns once all are done.
    /// `onProgress` receives (completed, total) on the main actor after each file.
    public static func process(
        _ urls: [URL],
        _ selection: BatchSelection,
        policy: OutputPolicy = .current,
        onProgress: @escaping @MainActor @Sendable (Int, Int) -> Void = { _, _ in }
    ) async -> ProcessingResult {
        let total = urls.count
        var succeeded: [URL] = []
        var failed: [(url: URL, error: Error)] = []

        await withTaskGroup(of: (URL, Result<URL, Error>).self) { group in
            var pending = urls.makeIterator()

            func addNext() -> Bool {
                guard let url = pending.next() else { return false }
                group.addTask(priority: .userInitiated) {
                    (url, Result { try processFile(url, selection, policy: policy) })
                }
                return true
            }

            for _ in 0..<maxConcurrentFiles where !addNext() { break }

            for await (url, result) in group {
                switch result {
                case .success(let output): succeeded.append(output)
                case .failure(let error): failed.append((url, error))
                }
                await onProgress(succeeded.count + failed.count, total)
                _ = addNext()
            }
        }

        return ProcessingResult(succeeded: succeeded, failed: failed)
    }

    /// Applies every selected step to one file and writes it once.
    /// Returns the output URL, or `url` unchanged when there was nothing to write.
    static func processFile(_ url: URL, _ selection: BatchSelection, policy: OutputPolicy) throws -> URL {
        // Finder-vended URLs may be security scoped
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        var (image, properties) = try ConversionEngine.readImage(from: url)
        let targetFormat = selection.format ?? ImageFormat(fileExtension: url.pathExtension) ?? .jpeg
        var needsWrite = selection.format != nil

        if let resize = selection.resize {
            let originalSize = CGSize(width: image.width, height: image.height)
            let newSize = ResizeEngine.size(for: image, operation: resize, proportional: policy.isProportional)
            if !FileOutputManager.shouldSkip(originalSize: originalSize, newSize: newSize, policy: policy) {
                image = try ResizeEngine.resize(image, toSize: newSize)
                needsWrite = true
            }
        }

        if let dpi = selection.dpi {
            properties = DPIEngine.updatedProperties(properties, dpi: dpi, for: targetFormat)
            needsWrite = true
        }

        guard needsWrite else { return url }

        let output = selection.format.map {
            FileOutputManager.outputURL(for: url, targetFormat: $0, policy: policy)
        } ?? FileOutputManager.outputURL(for: url, policy: policy)

        try ConversionEngine.writeImage(image, properties: properties, to: output, format: targetFormat)

        if selection.format != nil && output.path != url.path {
            FileOutputManager.deleteOriginal(url, policy: policy)
        }
        return output
    }
}
