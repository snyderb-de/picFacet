import Foundation

struct FileOutputManager {

    // MARK: - Output URL

    /// Output URL for a format-conversion operation (extension changes).
    static func outputURL(for inputURL: URL, targetFormat: ImageFormat, policy: OutputPolicy) -> URL {
        let dir = outputDirectory(for: inputURL, policy: policy)
        let base = inputURL.deletingPathExtension().lastPathComponent
        let candidate = dir
            .appendingPathComponent(base)
            .appendingPathExtension(targetFormat.fileExtension)

        // The source and output are different files (different extension), so
        // overwriteSource here controls whether we clobber an existing output file.
        if FileManager.default.fileExists(atPath: candidate.path) && !policy.overwriteSource {
            return deduplicated(candidate)
        }
        return candidate
    }

    /// Output URL for an in-place operation where format stays the same (resize, DPI).
    static func outputURL(for inputURL: URL, policy: OutputPolicy) -> URL {
        if policy.overwriteSource {
            return inputURL
        }
        let dir = outputDirectory(for: inputURL, policy: policy)
        let base = inputURL.deletingPathExtension().lastPathComponent
        let ext  = inputURL.pathExtension
        let candidate = dir.appendingPathComponent(base).appendingPathExtension(ext)

        // Avoid a silent collision when the output folder is the same as the source folder
        if candidate.path == inputURL.path {
            return dir.appendingPathComponent("\(base)-picfacet").appendingPathExtension(ext)
        }
        return candidate
    }

    // MARK: - Staging

    /// Hidden temp file in the output's folder, so committing it is a same-volume move.
    static func stagingURL(for output: URL) -> URL {
        output.deletingLastPathComponent()
            .appendingPathComponent(".picfacet-\(UUID().uuidString)")
            .appendingPathExtension(output.pathExtension)
    }

    /// Moves a staged file into place, replacing whatever is at `output`.
    static func commit(_ staged: URL, to output: URL) throws {
        if FileManager.default.fileExists(atPath: output.path) {
            _ = try FileManager.default.replaceItemAt(output, withItemAt: staged)
        } else {
            try FileManager.default.moveItem(at: staged, to: output)
        }
    }

    static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    // MARK: - Cleanup

    static func deleteOriginal(_ url: URL, policy: OutputPolicy) {
        guard policy.deleteOriginalAfterConvert else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private helpers

    private static func outputDirectory(for url: URL, policy: OutputPolicy) -> URL {
        policy.customOutputFolder ?? url.deletingLastPathComponent()
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
