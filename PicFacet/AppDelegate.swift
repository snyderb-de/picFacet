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
        
        applySavedAppearance()
        
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

    /// Receives files handed over by the Finder Sync extension's top-level
    /// "PicFacet…" item (or dropped on the app icon).
    func application(_ application: NSApplication, open urls: [URL]) {
        let images = urls.filter { $0.isImageFile }
        NSLog("[PicFacet] open(urls:) — %d image(s)", images.count)
        guard !images.isEmpty else { return }
        ChooserWindowController.shared.show(urls: images)
    }

    private func applySavedAppearance() {
        switch PicFacetSettings.shared.appAppearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}
