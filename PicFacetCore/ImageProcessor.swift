import Foundation
import CoreGraphics

/// Orchestrates all image processing. Max 4 concurrent jobs.
/// Progress and completion callbacks always fire on the main queue.
public final class ImageProcessor {
    public static let shared = ImageProcessor()

    private let queue: OperationQueue = {
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 4
        q.qualityOfService = .userInitiated
        return q
    }()

    private init() {}

    // MARK: - Public API

    public func convert(
        _ urls: [URL],
        to format: ImageFormat,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void
    ) {
        let settings = PicFacetSettings.shared
        batch(urls: urls, onProgress: onProgress, onComplete: onComplete) { url in
            let (image, props) = try ConversionEngine.readImage(from: url)
            let out = FileOutputManager.outputURL(for: url, targetFormat: format, settings: settings)
            try ConversionEngine.writeImage(image, properties: props, to: out, format: format)
            if out.path != url.path {
                FileOutputManager.deleteOriginal(url, settings: settings)
            }
            return out
        }
    }

    public func resize(
        _ urls: [URL],
        byPercent percent: Double,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void
    ) {
        resizeImpl(urls: urls, onProgress: onProgress, onComplete: onComplete) { image in
            ResizeEngine.size(for: image, byPercent: percent)
        }
    }

    public func resize(
        _ urls: [URL],
        maxWidth width: Int,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void
    ) {
        let proportional = PicFacetSettings.shared.isProportional
        resizeImpl(urls: urls, onProgress: onProgress, onComplete: onComplete) { image in
            ResizeEngine.size(for: image, maxWidth: width, proportional: proportional)
        }
    }

    public func resize(
        _ urls: [URL],
        maxHeight height: Int,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void
    ) {
        let proportional = PicFacetSettings.shared.isProportional
        resizeImpl(urls: urls, onProgress: onProgress, onComplete: onComplete) { image in
            ResizeEngine.size(for: image, maxHeight: height, proportional: proportional)
        }
    }

    public func changeDPI(
        _ urls: [URL],
        to dpi: Int,
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void
    ) {
        let settings = PicFacetSettings.shared
        batch(urls: urls, onProgress: onProgress, onComplete: onComplete) { url in
            let (image, props) = try ConversionEngine.readImage(from: url)
            let format = ImageFormat(fileExtension: url.pathExtension) ?? .jpeg
            let updatedProps = DPIEngine.updatedProperties(props, dpi: dpi, for: format)
            let out = FileOutputManager.outputURL(for: url, settings: settings)
            try ConversionEngine.writeImage(image, properties: updatedProps, to: out, format: format)
            return out
        }
    }

    // MARK: - Private

    private func resizeImpl(
        urls: [URL],
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void,
        sizeBlock: @escaping (CGImage) -> CGSize
    ) {
        let settings = PicFacetSettings.shared
        batch(urls: urls, onProgress: onProgress, onComplete: onComplete) { url in
            let (image, props) = try ConversionEngine.readImage(from: url)
            let newSize = sizeBlock(image)
            let originalSize = CGSize(width: image.width, height: image.height)

            if FileOutputManager.shouldSkip(originalSize: originalSize, newSize: newSize, settings: settings) {
                return url // No-op, return original path
            }

            let resized = try ResizeEngine.resize(image, toSize: newSize)
            let format = ImageFormat(fileExtension: url.pathExtension) ?? .jpeg
            let out = FileOutputManager.outputURL(for: url, settings: settings)
            try ConversionEngine.writeImage(resized, properties: props, to: out, format: format)
            return out
        }
    }

    /// Generic batch executor. Runs each URL through `work` on the shared queue,
    /// accumulates results, fires progress on main queue, then completion.
    private func batch(
        urls: [URL],
        onProgress: @escaping (Int, Int) -> Void,
        onComplete: @escaping (ProcessingResult) -> Void,
        work: @escaping (URL) throws -> URL
    ) {
        let total = urls.count
        guard total > 0 else {
            DispatchQueue.main.async { onComplete(ProcessingResult(succeeded: [], failed: [])) }
            return
        }

        var succeeded: [URL] = []
        var failed: [(url: URL, error: Error)] = []
        var completed = 0
        let lock = NSLock()
        let group = DispatchGroup()

        for url in urls {
            group.enter()
            queue.addOperation {
                defer { group.leave() }

                // Sandboxed extensions must explicitly unlock Finder-vended URLs
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }

                do {
                    let output = try work(url)
                    lock.lock()
                    succeeded.append(output)
                    completed += 1
                    let c = completed
                    lock.unlock()
                    DispatchQueue.main.async { onProgress(c, total) }
                } catch {
                    lock.lock()
                    failed.append((url, error))
                    completed += 1
                    let c = completed
                    lock.unlock()
                    DispatchQueue.main.async { onProgress(c, total) }
                }
            }
        }

        group.notify(queue: .main) {
            onComplete(ProcessingResult(succeeded: succeeded, failed: failed))
        }
    }
}
