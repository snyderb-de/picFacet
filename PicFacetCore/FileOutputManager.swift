import Foundation

struct FileOutputManager {

    // MARK: - Output URL

    /// Output URL for a format-conversion operation (extension changes).
    static func outputURL(for inputURL: URL, targetFormat: ImageFormat, settings: PicFacetSettings) -> URL {
        let dir = outputDirectory(for: inputURL, settings: settings)
        let base = inputURL.deletingPathExtension().lastPathComponent
        let candidate = dir
            .appendingPathComponent(base)
            .appendingPathExtension(targetFormat.fileExtension)

        // The source and output are different files (different extension), so
        // overwriteSource here controls whether we clobber an existing output file.
        if FileManager.default.fileExists(atPath: candidate.path) && !settings.overwriteSource {
            return deduplicated(candidate)
        }
        return candidate
    }

    /// Output URL for an in-place operation where format stays the same (resize, DPI).
    static func outputURL(for inputURL: URL, settings: PicFacetSettings) -> URL {
        if settings.overwriteSource {
            return inputURL
        }
        let dir = outputDirectory(for: inputURL, settings: settings)
        let base = inputURL.deletingPathExtension().lastPathComponent
        let ext  = inputURL.pathExtension
        let candidate = dir.appendingPathComponent(base).appendingPathExtension(ext)

        // Avoid a silent collision when the output folder is the same as the source folder
        if candidate.path == inputURL.path {
            return dir.appendingPathComponent("\(base)-picfacet").appendingPathExtension(ext)
        }
        return candidate
    }

    // MARK: - Guards

    /// Returns true if the operation should be skipped per the "only if smaller" setting.
    static func shouldSkip(originalSize: CGSize, newSize: CGSize, settings: PicFacetSettings) -> Bool {
        guard settings.onlyIfSmaller else { return false }
        // Skip when the new dimensions are not smaller in at least one axis
        return newSize.width >= CGFloat(1) &&
               newSize.height >= CGFloat(1) &&
               newSize.width >= originalSize.width &&
               newSize.height >= originalSize.height
    }

    // MARK: - Cleanup

    static func deleteOriginal(_ url: URL, settings: PicFacetSettings) {
        guard settings.deleteOriginalAfterConvert else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private helpers

    private static func outputDirectory(for url: URL, settings: PicFacetSettings) -> URL {
        if let custom = settings.customOutputFolder {
            return URL(fileURLWithPath: custom)
        }
        return url.deletingLastPathComponent()
    }

    private static func deduplicated(_ url: URL) -> URL {
        let dir  = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext  = url.pathExtension
        var counter = 1
        var candidate = url
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir
                .appendingPathComponent("\(base)-\(counter)")
                .appendingPathExtension(ext)
            counter += 1
        }
        return candidate
    }
}
