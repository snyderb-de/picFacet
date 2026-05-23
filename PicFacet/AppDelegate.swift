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
