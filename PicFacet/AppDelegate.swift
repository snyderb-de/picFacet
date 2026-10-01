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

    /// Receives files from the Finder Sync extension (`picfacet://open?path=…`)
    /// or dropped on the app icon.
    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.flatMap { url -> [URL] in
            guard url.scheme == "picfacet" else { return [url] }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            return items.filter { $0.name == "path" }
                .compactMap { $0.value }
                .map { URL(fileURLWithPath: $0) }
        }
        let images = files.filter { $0.isImageFile && FileManager.default.fileExists(atPath: $0.path) }
        NSLog("[PicFacet] open(urls:) — %d image(s)", images.count)
        guard !images.isEmpty else { return }
        ChooserWindowController.shared.show(urls: images)
    }
}
