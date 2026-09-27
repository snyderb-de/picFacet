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

    private func run(_ pboard: NSPasteboard, _ selection: BatchSelection) {
        let urls = imageURLs(from: pboard)
        NSLog("[PicFacet] Service fired — %d image(s)", urls.count)
        guard !urls.isEmpty else { return }
        let policy = PicFacetSettings.shared.outputPolicy
        Task {
            let result = await ImageProcessor.process(urls, selection, policy: policy) { done, total in
                NSLog("[PicFacet] progress %d/%d", done, total)
            }
            NSLog("[PicFacet] done — ok=%d failed=%d",
                  result.succeeded.count, result.failed.count)
            for f in result.failed {
                NSLog("[PicFacet] fail %@: %@",
                      f.url.lastPathComponent, f.error.localizedDescription)
            }
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
        run(pboard, BatchSelection(format: .jpeg))
    }
    @objc func convertToPNG(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .png))
    }
    @objc func convertToWebP(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .webp))
    }
    @objc func convertToTIFF(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .tiff))
    }
    @objc func convertToGIF(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .gif))
    }
    @objc func convertToBMP(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .bmp))
    }
    @objc func convertToHEIC(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(format: .heic))
    }

    // MARK: - Resize presets

    @objc func resize25(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(resize: .percent(25)))
    }
    @objc func resize50(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(resize: .percent(50)))
    }
    @objc func resize75(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(resize: .percent(75)))
    }

    // MARK: - DPI presets

    @objc func dpi72(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(dpi: 72))
    }
    @objc func dpi150(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(dpi: 150))
    }
    @objc func dpi300(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(dpi: 300))
    }
    @objc func dpi600(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        run(pboard, BatchSelection(dpi: 600))
    }
}
