import AppKit
import PicFacetCore

/// Handles NSServices / Quick Actions invoked from Finder's right-click menu.
///
/// Two @objc entry points match the `NSMessage` values in Info.plist's NSServices array.
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

    // MARK: - Direct actions

    /// Every non-chooser entry in Info.plist's NSServices sends this message;
    /// its NSUserData names the operation (see `BatchSelection(serviceCommand:)`).
    @objc func picFacetRun(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let userData, let selection = BatchSelection(serviceCommand: userData) else {
            NSLog("[PicFacet] Unknown service command: %@", userData ?? "nil")
            error.pointee = "PicFacet does not recognise this action." as NSString
            return
        }
        run(pboard, selection)
    }
}
