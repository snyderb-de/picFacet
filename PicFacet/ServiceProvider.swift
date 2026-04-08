import AppKit
import PicFacetCore

/// Handles NSServices / Quick Actions invoked from Finder's right-click menu.
///
/// Each @objc method matches an `NSMessage` entry in Info.plist's NSServices array.
/// macOS passes the selected files via the pasteboard as file URLs; we decode,
/// filter for images, and hand off to ImageProcessor.
final class ServiceProvider: NSObject {

    // MARK: - Pasteboard → URLs

    private func imageURLs(from pboard: NSPasteboard) -> [URL] {
        guard let items = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else {
            return []
        }
        return items.filter { $0.isImageFile }
    }

    private func run(_ pboard: NSPasteboard, _ work: ([URL]) -> Void) {
        let urls = imageURLs(from: pboard)
        NSLog("[PicFacet] Service fired — %d image(s)", urls.count)
        guard !urls.isEmpty else { return }
        work(urls)
    }

    private static let progress: (Int, Int) -> Void = { done, total in
        NSLog("[PicFacet] progress %d/%d", done, total)
    }
    private static let complete: (ProcessingResult) -> Void = { result in
        NSLog("[PicFacet] done — ok=%d failed=%d",
              result.succeeded.count, result.failed.count)
        for f in result.failed {
            NSLog("[PicFacet] fail %@: %@",
                  f.url.lastPathComponent, f.error.localizedDescription)
        }
    }

    // MARK: - Chooser

    @objc func picFacetChooser(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = imageURLs(from: pboard)
        NSLog("[PicFacet] Chooser fired — %d image(s)", urls.count)
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            ChooserWindowController.shared.show(urls: urls)
        }
    }

    // MARK: - Convert

    @objc func convertToJPEG(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .jpeg, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToPNG(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .png, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToWebP(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .webp, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToTIFF(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .tiff, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToGIF(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .gif, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToBMP(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .bmp, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func convertToHEIC(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.convert($0, to: .heic, onProgress: Self.progress, onComplete: Self.complete) }
    }

    // MARK: - Resize presets

    @objc func resize25(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.resize($0, byPercent: 25, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func resize50(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.resize($0, byPercent: 50, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func resize75(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.resize($0, byPercent: 75, onProgress: Self.progress, onComplete: Self.complete) }
    }

    // MARK: - DPI presets

    @objc func dpi72(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.changeDPI($0, to: 72, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func dpi150(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.changeDPI($0, to: 150, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func dpi300(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.changeDPI($0, to: 300, onProgress: Self.progress, onComplete: Self.complete) }
    }
    @objc func dpi600(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard) { ImageProcessor.shared.changeDPI($0, to: 600, onProgress: Self.progress, onComplete: Self.complete) }
    }
}
