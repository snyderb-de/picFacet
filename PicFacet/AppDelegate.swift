import AppKit
import PicFacetCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("========================================")
        print("🚀 PICFACET APP LAUNCHED!")
        print("========================================")
        NSLog("[AppDelegate] App finished launching")
        NSApp.setActivationPolicy(.accessory)
        NSLog("[AppDelegate] Activation policy set to .accessory")
        
        PicFacetSettings.shared.migrateLegacyAppGroupIfNeeded()
        AppearanceController.apply(PicFacetSettings.shared.appAppearance)
        
        menuBarController = MenuBarController()
        NSLog("[AppDelegate] MenuBarController created")

        // Register as the services provider so Finder right-click items
        // (declared in Info.plist NSServices) call into ServiceProvider.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        NSLog("[PicFacet] Services provider registered")

        BackgroundWatching.restoreIfNeeded()
        FolderWatchController.shared.reload()
        // Created up front so the Finder extension can read it for recipe links.
        _ = PicFacetSettings.shared.recipeRunToken

        OnboardingWindowController.shared.showIfFirstLaunch()
        
        print("========================================")
        print("✅ MENU BAR SHOULD BE VISIBLE NOW")
        print("========================================")
    }

    /// Most paths a single `picfacet://` link may carry. Real Finder selections
    /// can be large; this only stops an absurd link from building a huge list.
    private static let maxLinkedPaths = 500

    /// Receives files from the Finder Sync extension or dropped on the app icon:
    ///   - `picfacet://open?path=…` opens the Chooser.
    ///   - `picfacet://run?recipe=<id>&token=<t>&path=…` runs a saved recipe.
    ///
    /// Any local app or web page can send a `picfacet://` link, so it is
    /// treated as untrusted input: only absolute paths to existing regular
    /// image files are kept. A `run` link processes files straight away only
    /// when it carries the token the extension reads from the shared App
    /// Group; otherwise it just opens the Chooser with the recipe loaded, and
    /// nothing is processed until the user clicks Start Processing.
    func application(_ application: NSApplication, open urls: [URL]) {
        var recipe: Recipe?
        var trusted = false
        let files = urls.flatMap { url -> [URL] in
            guard url.scheme == "picfacet" else { return [url] }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if url.host == "run" {
                let value = { (name: String) in items.first { $0.name == name }?.value }
                recipe = value("recipe").flatMap(UUID.init(uuidString:)).flatMap(PicFacetSettings.shared.recipe(id:))
                trusted = value("token") == PicFacetSettings.shared.recipeRunToken
            }
            return items.filter { $0.name == "path" }
                .compactMap { $0.value }
                .filter { $0.hasPrefix("/") }
                .prefix(Self.maxLinkedPaths)
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
        }
        let images = files.filter { url in
            guard url.isProcessableFile else { return false }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
        NSLog("[PicFacet] open(urls:) — %d image(s), recipe %@", images.count, recipe?.name ?? "none")
        guard !images.isEmpty else { return }
        if let recipe, trusted {
            QuickRun.run(images, recipe.selection, policy: PicFacetSettings.shared.outputPolicy, title: recipe.name)
        } else {
            ChooserWindowController.shared.show(urls: images, selection: recipe?.selection)
        }
    }
}
