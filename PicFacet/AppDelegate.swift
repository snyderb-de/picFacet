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
        
        AppearanceController.apply(PicFacetSettings.shared.appAppearance)
        
        menuBarController = MenuBarController()
        NSLog("[AppDelegate] MenuBarController created")

        // Register as the services provider so Finder right-click items
        // (declared in Info.plist NSServices) call into ServiceProvider.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        NSLog("[PicFacet] Services provider registered")

        OnboardingWindowController.shared.showIfFirstLaunch()
        
        print("========================================")
        print("✅ MENU BAR SHOULD BE VISIBLE NOW")
        print("========================================")
    }

    /// Most paths a single `picfacet://` link may carry. Real Finder selections
    /// can be large; this only stops an absurd link from building a huge list.
    private static let maxLinkedPaths = 500

    /// Receives files from the Finder Sync extension (`picfacet://open?path=…`)
    /// or dropped on the app icon.
    ///
    /// Any local app or web page can send a `picfacet://` link, so it is
    /// treated as untrusted input: only absolute paths to existing regular
    /// image files are kept, and it can only populate the Chooser. Nothing is
    /// processed until the user clicks Start Processing.
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.flatMap { url -> [URL] in
            guard url.scheme == "picfacet" else { return [url] }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return items.filter { $0.name == "path" }
                .compactMap { $0.value }
                .filter { $0.hasPrefix("/") }
                .prefix(Self.maxLinkedPaths)
                .map { URL(fileURLWithPath: $0).standardizedFileURL }
        }
        let images = files.filter { url in
            guard url.isImageFile else { return false }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
        NSLog("[PicFacet] open(urls:) — %d image(s)", images.count)
        guard !images.isEmpty else { return }
        ChooserWindowController.shared.show(urls: images)
    }
}
