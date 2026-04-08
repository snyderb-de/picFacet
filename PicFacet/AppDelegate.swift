import AppKit
import PicFacetCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()

        // Register as the services provider so Finder right-click items
        // (declared in Info.plist NSServices) call into ServiceProvider.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        NSLog("[PicFacet] Services provider registered")

        OnboardingWindowController.shared.showIfFirstLaunch()
    }
}
