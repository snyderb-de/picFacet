import Cocoa
import FinderSync
import UniformTypeIdentifiers

/// Adds a top-level "PicFacet…" item to Finder's right-click menu for images.
///
/// The extension is sandboxed and does no image work itself: it hands the
/// selected paths to the main app in a `picfacet://open?path=…` URL (a sandboxed
/// extension can't open the files themselves). The app opens the chooser; see
/// `AppDelegate.application(_:open:)`.
final class FinderSync: FIFinderSync {

    /// The app that contains this extension (App.app/Contents/PlugIns/X.appex).
    /// Not looked up by bundle ID: other copies of the app (e.g. in /Applications)
    /// would be picked instead of the one this extension shipped with.
    private static let hostAppURL = Bundle.main.bundleURL
        .deletingLastPathComponent()  // PlugIns
        .deletingLastPathComponent()  // Contents
        .deletingLastPathComponent()  // App.app

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
        guard !urls.isEmpty else {
            NSLog("[PicFacetFinderSync] nothing to open")
            return
        }
        let appURL = Self.hostAppURL
        var components = URLComponents()
        components.scheme = "picfacet"
        components.host = "open"
        components.queryItems = urls.map { URLQueryItem(name: "path", value: $0.path) }
        guard let openURL = components.url else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([openURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error { NSLog("[PicFacetFinderSync] open failed: %@", error.localizedDescription) }
        }
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }
}
