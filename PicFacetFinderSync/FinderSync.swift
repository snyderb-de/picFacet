import Cocoa
import FinderSync
import UniformTypeIdentifiers

/// Adds a top-level "PicFacet…" item to Finder's right-click menu for images,
/// plus a "PicFacet Recipes" submenu listing the user's saved recipes.
///
/// The extension is sandboxed and does no image work itself: it hands the
/// selected paths to the main app in a `picfacet://open?path=…` or
/// `picfacet://run?recipe=…&token=…&path=…` URL (a sandboxed extension can't
/// open the files themselves). See `AppDelegate.application(_:open:)`.
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

        let recipes = SharedRecipes.load()
        if !recipes.isEmpty {
            let submenu = NSMenu(title: "PicFacet Recipes")
            // Finder copies these items, so represent the recipe by its index (tag).
            for (index, recipe) in recipes.enumerated() {
                let recipeItem = NSMenuItem(title: recipe.name, action: #selector(runRecipe(_:)), keyEquivalent: "")
                recipeItem.target = self
                recipeItem.tag = index
                submenu.addItem(recipeItem)
            }
            let parent = NSMenuItem(title: "PicFacet Recipes", action: nil, keyEquivalent: "")
            parent.submenu = submenu
            menu.addItem(parent)
        }
        return menu
    }

    @objc private func openChooser(_ sender: Any?) {
        send(host: "open", extra: [])
    }

    @objc private func runRecipe(_ sender: NSMenuItem) {
        let recipes = SharedRecipes.load()
        guard recipes.indices.contains(sender.tag), let token = SharedRecipes.token() else {
            NSLog("[PicFacetFinderSync] recipe %ld unavailable", sender.tag)
            return
        }
        send(host: "run", extra: [
            URLQueryItem(name: "recipe", value: recipes[sender.tag].id),
            URLQueryItem(name: "token", value: token)
        ])
    }

    private func send(host: String, extra: [URLQueryItem]) {
        let urls = (FIFinderSyncController.default().selectedItemURLs() ?? []).filter(Self.isImage)
        guard !urls.isEmpty else {
            NSLog("[PicFacetFinderSync] nothing to open")
            return
        }
        let appURL = Self.hostAppURL
        var components = URLComponents()
        components.scheme = "picfacet"
        components.host = host
        components.queryItems = extra + urls.map { URLQueryItem(name: "path", value: $0.path) }
        guard let openURL = components.url else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = host == "open"
        NSWorkspace.shared.open([openURL], withApplicationAt: appURL, configuration: config) { _, error in
            if let error { NSLog("[PicFacetFinderSync] open failed: %@", error.localizedDescription) }
        }
    }

    private static func isImage(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image) || type.conforms(to: .pdf)
    }
}

/// The app's recipes, read from the shared App Group defaults. Only the
/// fields the menu needs are decoded; the app owns the full format.
private enum SharedRecipes {
    struct Entry: Decodable {
        let id: String
        let name: String
    }

    private static var defaults: UserDefaults? {
        let group = Bundle.main.object(forInfoDictionaryKey: "PicFacetAppGroup") as? String ?? "group.com.picfacet.shared"
        return UserDefaults(suiteName: group)
    }

    static func load() -> [Entry] {
        guard let data = defaults?.data(forKey: "recipes") else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    static func token() -> String? {
        defaults?.string(forKey: "recipeRunToken")
    }
}
