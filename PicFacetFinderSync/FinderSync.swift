import Cocoa
import FinderSync
import UniformTypeIdentifiers

/// Adds a top-level "PicFacet…" item to Finder's right-click menu for images.
///
/// The extension is sandboxed and does no image work itself: it hands the
/// selected files to the main app, which opens the chooser (see
/// `AppDelegate.application(_:open:)`).
final class FinderSync: FIFinderSync {

    private static let mainAppBundleID = "com.picfacet.app"

    override init() {
        super.init()
        // Watch everything so the menu shows in any folder.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else { return nil }
        let urls = FIFinderSyncController.default().selectedItemURLs() ?? []
        guard urls.contains(where: Self.isImage) else { return nil }

        let menu = NSMenu(title: "")
        let item = NSMenuItem(title: "PicFacet…", action: #selector(openChooser(_:)), keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openChooser(_ sender: Any?) {
        let urls = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter(Self.isImage)
        guard !urls.isEmpty,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.mainAppBundleID)
        else {
            NSLog("[PicFacetFinderSync] nothing to open (urls=%d)", urls.count)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: config) { _, error in
            if let error { NSLog("[PicFacetFinderSync] open failed: %@", error.localizedDescription) }
        }
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
